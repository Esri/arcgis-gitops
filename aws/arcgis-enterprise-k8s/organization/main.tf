/**
 * # Organization Terraform Module for ArcGIS Enterprise on Kubernetes
 *
 * The module deploys ArcGIS Enterprise on Kubernetes in Amazon EKS cluster and creates an ArcGIS Enterprise organization.
 *
 * The module uses [Helm Charts for ArcGIS Enterprise on Kubernetes](https://links.esri.com/enterprisekuberneteshelmcharts/1.2.0/deploy-guide).
 *
 * The following table explains the compatibility of chart versions and ArcGIS Enterprise on Kubernetes.
 * 
 * Helm Chart Version | ArcGIS Enterprise version | Initial deployment using `helm install` command | Release upgrade using `helm upgrade` command | Patch update using `helm upgrade` command | Description |
 * --- | --- | --- | --- | --- | --- |
 * v1.1.0 | 11.1.0.3923 | Supported     | Supported      | Not applicable | Helm chart for deploying 11.1 or upgrading 11.0 to 11.1 |
 * v1.1.4 | 11.1.0.4115 | Not supported | Not applicable | Supported      | Helm chart to apply the 11.1 Q4 2023 Bug Fix Update |
 * v1.2.0 | 11.2.0.5207 | Supported     | Supported      | Not applicable | Helm chart for deploying 11.2 or upgrading 11.1 to 11.2 | 
 * v1.2.1 | 11.2.0.5500 | Not supported | Not applicable | Supported      | Helm chart to apply the 11.2 Help Language Pack Update |
 *
 * The module also:
 * 
 * * Creates an S3 bucket for the organization object store and registers it with the deployment.
 * * Registers backup store using S3 bucket specified by "/arcgis/${var.site_id}/s3/backup" SSM parameter.
 * * Updates the DR settings to use the specified storage class and size for staging volume.
 * * Creates a Kubernetes pod to execute Enterprise Admin CLI commands.
 *
 * The deployment's Monitoring Subsystem consists of:
 *
 * * An SNS topic with a subscription for the primary site administrator.
 * * A CloudWatch alarm that monitors the ingress ALB target group and post to the SNS topic if the number of unhealthy instances in nonzero. 
 * * A CloudWatch dashboard that displays the CloudWatch alerts, metrics, and container logs of the deployment.
 *
 * ## Requirements
 * 
 * On the machine where Terraform is executed:
 * 
 * * AWS credentials must be configured.
 * * AWS region must be specified by AWS_DEFAULT_REGION environment variable.
 * * EKS cluster configuration information must be provided in ~/.kube/config file.
 */

terraform {
  backend "s3" {
    key = "arcgis-enterprise/aws/arcgis-enterprise-k8s/organization.tfstate"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.22"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.26"
    }
  }

  required_version = ">= 1.1.9"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "aws" {
  default_tags {
    tags = {
      ArcGISSiteId       = var.site_id
      ArcGISDeploymentId = var.deployment_id
    }
  }
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_ssm_parameter" "s3_backup" {
  name = "/arcgis/${var.site_id}/s3/backup"
}

locals {
  # Currently only ECR with IAM authentication is supported by the modified Helm chart
  container_registry          = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com"
  enterprise_admin_cli_image  = "${local.container_registry}/enterprise-admin-cli:${var.enterprise_admin_cli_version}"

  # The EKS cluster uses IAM authentication for ECR access, while the Helm charts require setting container reqistry credentials.
  container_registry_username = "AWS"
  container_registry_password = "AWS"
}

# Create S3 bucket for the organization object store
resource "aws_s3_bucket" "object_store" {
  bucket_prefix = "${var.deployment_id}-object-store"
  force_destroy = true
}

resource "local_sensitive_file" "license_file" {
  content  = file(var.authorization_file_path)
  filename = "./helm-charts/arcgis-enterprise/${var.helm_charts_version}/user-inputs/license.json"
}

resource "local_sensitive_file" "cloud_config_json_file" {
  content = (var.cloud_config_json_file_path != null ?
    file(var.cloud_config_json_file_path) :
    jsonencode([{
      name = "AWS"
      credential = {
        type = "IAM-ROLE"
      }
      cloudServices = [{
        name  = "AWS S3"
        type  = "objectStore"
        usage = "DEFAULT"
        connection = {
          bucketName = aws_s3_bucket.object_store.bucket
          region     = data.aws_region.current.name
          rootDir    = var.deployment_id
        }
        category = "storage"
      }]
  }]))
  filename = "./helm-charts/arcgis-enterprise/${var.helm_charts_version}/user-inputs/cloud-config.json"
}

resource "helm_release" "arcgis_enterprise" {
  name      = "arcgis"
  chart     = "./helm-charts/arcgis-enterprise/${var.helm_charts_version}"
  namespace = var.deployment_id
  timeout   = 21600 # 6 hours

  set_sensitive {
    name  = "configure.admin.password"
    value = var.admin_password
  }

  set_sensitive {
    name  = "configure.securityQuestionAnswer"
    value = var.security_question_answer
  }

  set_sensitive {
    name  = "upgrade.token"
    value = var.upgrade_token
  }

  values = [
    "${file("./helm-charts/arcgis-enterprise/${var.helm_charts_version}/configure.yaml")}",
    yamlencode({
      image = {
        registry   = local.container_registry
        repository = var.image_repository_prefix
        username   = local.container_registry_username
        password   = local.container_registry_password
      }
      install = {
        enterpriseFQDN              = var.deployment_fqdn
        context                     = var.arcgis_enterprise_context
        allowedPrivilegedContainers = true
        configureWaitTimeMin        = var.configure_wait_time_min
        ingress = {
          tls = {
            selfSignCN = var.deployment_fqdn
          }
        }
        k8sClusterDomain = var.k8s_cluster_domain
      }
      common = {
        verbose = var.common_verbose
      }
      configure = {
        enabled           = var.configure_enterprise_org
        systemArchProfile = var.system_arch_profile
        licenseFile       = "user-inputs/license.json"
        licenseTypeId     = var.license_type_id
        admin = {
          username = var.admin_username
          email     = var.admin_email
          firstName = var.admin_first_name
          lastName  = var.admin_last_name
        }
        securityQuestionIndex = var.security_question_index
        cloudConfigJsonFilename = "user-inputs/cloud-config.json"
        logSetting              = var.log_setting
        logRetentionMaxDays     = var.log_retention_max_days
        storage                 = var.storage
      }
      upgrade = {
        mandatoryUpdateTargetId = var.mandatory_update_target_id
        licenseFile             = "user-inputs/license.json"
      }
    })
  ]

  depends_on = [
    local_sensitive_file.license_file,
    local_sensitive_file.cloud_config_json_file
  ]
}

resource "kubernetes_secret" "admin_cli_credentials" {
  metadata {
    name      = "admin-cli-credentials"
    namespace = var.deployment_id
  }

  data = {
    username = var.admin_username
    password = var.admin_password
  }
}

# Kubernetes pod used to execute Enterprise Admin CLI commands using "kubectl exec".
resource "kubernetes_pod" "enterprise_admin_cli" {
  metadata {
    name = "enterprise-admin-cli"
    namespace = var.deployment_id
  }

  spec {
    container {
      name  = "enterprise-admin-cli"
      image = local.enterprise_admin_cli_image
      env {
        name = "ARCGIS_ENTERPRISE_URL"
        value = "https://${var.deployment_fqdn}/${var.arcgis_enterprise_context}"
      }
      env {
        name = "ARCGIS_ENTERPRISE_USER"
        value_from {
          secret_key_ref {
            name = kubernetes_secret.admin_cli_credentials.metadata[0].name
            key  = "username"
          }
        }
      }
      env {
        name = "ARCGIS_ENTERPRISE_PASSWORD"
        value_from {
          secret_key_ref {
            name = kubernetes_secret.admin_cli_credentials.metadata[0].name
            key  = "password"
          }
        }
      }
      resources {
        limits = {
          cpu    = "500m"
          memory = "256Mi"
        }
        requests = {
          cpu    = "50m"
          memory = "128Mi"
        }
      }
      command = [
        "sleep", "infinity"
      ]
    }
    restart_policy = "Always"
  }
}

# Update the DR settings
resource "kubernetes_job" "update_dr_settings" {
  metadata {
    name      = "update-dr-settings"
    namespace = var.deployment_id
  }
  spec {
    template {
      metadata {}
      spec {
        container {
          name  = "enterprise-admin-cli"
          image = local.enterprise_admin_cli_image
          env {
            name = "ARCGIS_ENTERPRISE_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.admin_cli_credentials.metadata[0].name
                key  = "username"
              }
            }
          }
          env {
            name = "ARCGIS_ENTERPRISE_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.admin_cli_credentials.metadata[0].name
                key  = "password"
              }
            }
          }
          resources {
            limits = {
              cpu    = "500m"
              memory = "256Mi"
            }
            requests = {
              cpu    = "50m"
              memory = "128Mi"
            }
          }
          command = [
            "gis", "update-dr-settings",
            "--url", "https://${var.deployment_fqdn}/${var.arcgis_enterprise_context}",
            "--storage-class", var.staging_volume_class,
            "--size", var.staging_volume_size,
            "--timeout", var.backup_job_timeout
          ]
        }
        restart_policy = "Never"
      }
    }
    backoff_limit = 1
  }
  wait_for_completion = true
  depends_on = [
    kubernetes_secret.admin_cli_credentials,
    helm_release.arcgis_enterprise
  ]
}

# Register default S3 backup store using S3 bucket specified by 
# "/arcgis/${var.site_id}/s3/backup" SSM parameter.
resource "kubernetes_job" "register_s3_backup_store" {
  metadata {
    name      = "register-s3-backup-store"
    namespace = var.deployment_id
  }
  spec {
    template {
      metadata {}
      spec {
        container {
          name  = "enterprise-admin-cli"
          image = local.enterprise_admin_cli_image
          env {
            name = "ARCGIS_ENTERPRISE_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.admin_cli_credentials.metadata[0].name
                key  = "username"
              }
            }
          }
          env {
            name = "ARCGIS_ENTERPRISE_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.admin_cli_credentials.metadata[0].name
                key  = "password"
              }
            }
          }
          resources {
            limits = {
              cpu    = "500m"
              memory = "256Mi"
            }
            requests = {
              cpu    = "50m"
              memory = "128Mi"
            }
          }
          command = [
            "gis", "register-s3-backup-store",
            "--url", "https://${var.deployment_fqdn}/${var.arcgis_enterprise_context}",
            "--store", "s3-backup-store",
            "--bucket", nonsensitive(data.aws_ssm_parameter.s3_backup.value),
            "--region", data.aws_region.current.name,
            "--root", var.deployment_id,
            "--is-default"
          ]
        }
        restart_policy = "Never"
      }
    }
    backoff_limit = 1
  }
  wait_for_completion = true
  depends_on = [
    kubernetes_secret.admin_cli_credentials,
    helm_release.arcgis_enterprise
  ]
}
