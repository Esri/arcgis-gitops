/**
 * # Organization Terraform Module for ArcGIS Enterprise on Kubernetes
 *
 * The module deploys ArcGIS Enterprise on Kubernetes in Amazon EKS cluster
 * and creates an ArcGIS Enterprise organization.
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

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

locals {
  # Currently only ECR with IAM authentication is supported by the modified Helm chart
  container_registry = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com"
  container_registry_username = "AWS"
  container_registry_password = "AWS"
}

resource "local_sensitive_file" "license_file" {
  content  = file(var.authorization_file_path)
  filename = "./helm-charts/arcgis-enterprise/${var.helm_charts_version}/user-inputs/license.json"
}

resource "local_sensitive_file" "cloud_config_json_file" {
  count = var.cloud_config_json_file_path == null ? 0 : 1
  content  = file(var.cloud_config_json_file_path)
  filename = "./helm-charts/arcgis-enterprise/${var.helm_charts_version}/user-inputs/cloud-config.json"
}

resource "helm_release" "arcgis_enterprise" {
  name      = "arcgis"
  chart     = "./helm-charts/arcgis-enterprise/${var.helm_charts_version}"
  namespace = var.deployment_id
  timeout   = 21600 # 6 hours

  values = [
    "${file("./helm-charts/arcgis-enterprise/${var.helm_charts_version}/configure.yaml")}",
    nonsensitive(yamlencode({
      image = {
        registry = local.container_registry
        repository = var.image_repository_prefix
        username = local.container_registry_username
        password = local.container_registry_password
      }
      install = {
        enterpriseFQDN = var.arcgis_enterprise_fqdn
        context = var.arcgis_enterprise_context
        allowedPrivilegedContainers = true
        configureWaitTimeMin = var.configure_wait_time_min
        ingress = {
          tls = {
            selfSignCN = var.arcgis_enterprise_fqdn
          }
        }
        k8sClusterDomain = var.k8s_cluster_domain
      }
      common = {
        verbose = var.common_verbose
      }
      configure = {
        enabled = var.configure_enterprise_org
        systemArchProfile = var.system_arch_profile
        licenseFile = "user-inputs/license.json"
        licenseTypeId = var.license_type_id
        admin = {
          username = var.admin_username
          password = var.admin_password
          email = var.admin_email
          firstName = var.admin_first_name
          lastName = var.admin_last_name
        }
        securityQuestionIndex = var.security_question_index
        securityQuestionAnswer = var.security_question_answer
        cloudConfigJsonFilename = var.cloud_config_json_file_path == null ? "" : "user-inputs/cloud-config.json" 
        logSetting = var.log_setting
        logRetentionMaxDays = var.log_retention_max_days
        storage = var.storage
      }
      upgrade = {
        token = var.upgrade_token
        mandatoryUpdateTargetId = var.mandatory_update_target_id
        licenseFile = "user-inputs/license.json"
      }
    }))
  ]

  depends_on = [
    local_sensitive_file.license_file,
    local_sensitive_file.cloud_config_json_file
  ]
}
