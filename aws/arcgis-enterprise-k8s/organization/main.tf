/**
 * # Organization Terraform Module for ArcGIS Enterprise on Kubernetes
 *
 * The module deploys ArcGIS Enterprise on Kubernetes in Amazon EKS cluster and creates an ArcGIS Enterprise organization.
 *
 * ![ArcGIS Enterprise on Kubernetes](arcgis-enterprise-k8s-organization.png "ArcGIS Enterprise on Kubernetes")  
 *
 * The module uses [Helm Charts for ArcGIS Enterprise on Kubernetes](https://links.esri.com/enterprisekuberneteshelmcharts/1.2.0/deploy-guide) distributed separately from the module.
 * The Helm charts package for the version used by the deployment must be extracted in the module's `helm-charts/arcgis-enterprise/<Helm charts version>` directory.
 *
 * The following table explains the compatibility of chart versions and ArcGIS Enterprise on Kubernetes.
 * 
 * Helm Chart Version | ArcGIS Enterprise version | Initial deployment using `helm install` command | Release upgrade using `helm upgrade` command | Patch update using `helm upgrade` command | Description |
 * --- | --- | --- | --- | --- | --- |
 * v1.2.0 | 11.2.0.5207 | Supported     | Supported      | Not applicable | Helm chart for deploying 11.2 or upgrading 11.1 to 11.2 |
 * v1.2.1 | 11.2.0.5500 | Not supported | Not applicable | Supported      | Helm chart to apply the 11.2 Help Language Pack Update |
 * v1.2.2 | 11.2.0.5505 | Not supported | Not applicable | Supported      | Helm chart to apply the 11.2 Q2 2024 Base Operating System Image Update |
 * v1.2.3 | 11.2.0.5510 | Not supported | Not applicable | Supported      | Helm chart to apply the 11.2 Q2 2024 Bug Fix Update | 
 * v1.3.0 | 11.3.0.5814 | Supported     | Supported      | Not applicable | Helm chart for deploying 11.3 or upgrading 11.2 to 11.3 | *
 *
 * The module creates a Kubernetes pod to execute Enterprise Admin CLI commands and updates the DR settings to use the specified storage class and size for staging volume.
 * For ArcGIS Enterprise versions 11.2 and newer the module also creates an S3 bucket for the organization object store, registers it with the deployment, 
 * and registers backup store using S3 bucket specified by "/arcgis/${var.site_id}/s3/backup" SSM parameter.
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

# Copyright 2024 Esri
#
# Licensed under the Apache License Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
 
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
  container_registry         = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com"
  enterprise_admin_cli_image = "${local.container_registry}/enterprise-admin-cli:${var.enterprise_admin_cli_version}"

  # The EKS cluster uses IAM authentication for ECR access, while the Helm charts require setting container reqistry credentials.
  container_registry_username = "AWS"
  container_registry_password = "AWS"

  configure_cloud_stores = true

  app_version = yamldecode(file("./helm-charts/arcgis-enterprise/${var.helm_charts_version}/Chart.yaml")).appVersion
  backup_store_suffix = replace(local.app_version, ".", "-")
  backup_store = "s3-backup-store-${local.backup_store_suffix}"
  backup_root_dir = "${var.deployment_id}/${local.app_version}"
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
    name      = "enterprise-admin-cli"
    namespace = var.deployment_id
  }

  spec {
    container {
      name  = "enterprise-admin-cli"
      image = local.enterprise_admin_cli_image
      env {
        name  = "ARCGIS_ENTERPRISE_URL"
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
        name = "ARCGIS_ENTERPRISE_PASSWORD_FILE"
        value = "/var/run/secrets/admin-cli-credentials/password"
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
      volume_mount {
        name       = "admin-cli-credentials"
        read_only  = true
        mount_path = "/var/run/secrets/admin-cli-credentials"
      }
    }
    volume {
      name = "admin-cli-credentials"
      secret {
        secret_name = kubernetes_secret.admin_cli_credentials.metadata[0].name
      }
    }
    restart_policy = "Always"
  }

  depends_on = [
    kubernetes_secret.admin_cli_credentials
  ]
}

# Create S3 bucket for the organization object store for versions 1.2.0 and newer
# if cloud_config_json_file_path is not specified.
resource "aws_s3_bucket" "object_store" {
  count = local.configure_cloud_stores && var.cloud_config_json_file_path == null ? 1 : 0
  bucket_prefix = "${var.deployment_id}-object-store"
  force_destroy = true
}

resource "local_sensitive_file" "license_file" {
  content  = file(var.authorization_file_path)
  filename = "./helm-charts/arcgis-enterprise/${var.helm_charts_version}/user-inputs/license.json"
}

# Create cloud-config.json file for cloud stores in the Helm chart's user-input diectory
# if the file path is specified either by cloud_config_json_file_path input variable
# or configured with the default setings.
resource "local_sensitive_file" "cloud_config_json_file" {
  count = local.configure_cloud_stores || var.cloud_config_json_file_path != null ? 1 : 0
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
          bucketName = aws_s3_bucket.object_store[0].bucket
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
          username  = var.admin_username
          email     = var.admin_email
          firstName = var.admin_first_name
          lastName  = var.admin_last_name
        }
        securityQuestionIndex   = var.security_question_index
        cloudConfigJsonFilename = local.configure_cloud_stores || var.cloud_config_json_file_path != null ? "user-inputs/cloud-config.json" : null
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
    local_sensitive_file.cloud_config_json_file,
    kubernetes_pod.enterprise_admin_cli
  ]
}

module "update_dr_settings" {
  source        = "./modules/cli-command"
  namespace     = var.deployment_id
  admin_cli_pod = kubernetes_pod.enterprise_admin_cli.metadata[0].name
  command = [
    "gis", "update-dr-settings",
    "--storage-class", var.staging_volume_class,
    "--size", var.staging_volume_size,
    "--timeout", var.backup_job_timeout
  ]
  depends_on = [
    helm_release.arcgis_enterprise
  ]
}

# Register default S3 backup store using S3 bucket specified by 
# "/arcgis/${var.site_id}/s3/backup" SSM parameter.
module "register_s3_backup_store" {
  count = local.configure_cloud_stores ? 1 : 0
  source        = "./modules/cli-command"
  namespace     = var.deployment_id
  admin_cli_pod = kubernetes_pod.enterprise_admin_cli.metadata[0].name
  command = [
    "gis", "register-s3-backup-store",
    "--store", local.backup_store,
    "--bucket", nonsensitive(data.aws_ssm_parameter.s3_backup.value),
    "--region", data.aws_region.current.name,
    "--root", local.backup_root_dir,
    "--is-default"
  ]
  depends_on = [
    module.update_dr_settings
  ]
}

# module "register_pv_backup_store" {
#   count = local.configure_cloud_stores ? 0 : 1
#   source        = "./modules/cli-command"
#   namespace     = var.deployment_id
#   admin_cli_pod = kubernetes_pod.enterprise_admin_cli.metadata[0].name
#   command = [
#     "gis", "register-pv-backup-store",
#     "--store", "pv-backup-store",
#     "--storage-class", "gp3",
#     "--size", "64Gi",
#     "--is-dynamic",
#     "--is-default"
#   ]
#   depends_on = [
#     module.update_dr_settings
#   ]
# }

module "monitoring" {
  source        = "./modules/monitoring"
  cluster_name  = var.site_id
  namespace     = var.deployment_id
}

resource "aws_sns_topic_subscription" "infrastructure_alarms" {
  topic_arn = module.monitoring.sns_topic_arn
  protocol  = "email"
  endpoint  = var.admin_email
}
