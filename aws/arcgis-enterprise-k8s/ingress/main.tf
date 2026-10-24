# Copyright 2024-2026 Esri
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
    key = "arcgis-enterprise/aws/arcgis-enterprise-k8s/ingress.tfstate"
  }

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.26"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.10"
    }
  }

  required_version = ">= 1.10.0"
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ArcGISAutomation   = "arcgis-gitops"
      ArcGISEnterpriseID = var.enterprise_id
      ArcGISDeploymentID = var.deployment_id
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

data "aws_ssm_parameter" "s3_logs" {
  name = "/arcgis/${var.enterprise_id}/s3/logs"
}

data "aws_ssm_parameter" "sns_topic" {
  name = "/arcgis/${var.enterprise_id}/sns-topics/enterprise-alarms"
}

data "aws_ssm_parameter" "vpc_id" {
  name = "/arcgis/${var.enterprise_id}/vpc/id"
}

data "aws_lb" "arcgis_enterprise_ingress" {
  tags = {
    "ingress.k8s.aws/stack" = "${var.deployment_id}/arcgis-enterprise-ingress"
  }

  depends_on = [
    kubernetes_ingress_v1.arcgis_enterprise
  ]
}

resource "kubernetes_namespace" "arcgis_enterprise" {
  metadata {
    name = var.deployment_id
    # annotations = {
    #   "instrumentation.opentelemetry.io/inject-java" = true
    # }
  }
}

resource "kubernetes_ingress_v1" "arcgis_enterprise" {
  wait_for_load_balancer = true
  metadata {
    namespace = var.deployment_id
    name      = "arcgis-enterprise-ingress"
    annotations = {
      "alb.ingress.kubernetes.io/scheme"                   = var.internal_load_balancer ? "internal" : "internet-facing"
      "alb.ingress.kubernetes.io/target-type"              = "ip"
      "alb.ingress.kubernetes.io/backend-protocol"         = "HTTPS"
      "alb.ingress.kubernetes.io/listen-ports"             = "[{\"HTTPS\":443}]"
      "alb.ingress.kubernetes.io/healthcheck-port"         = "443"
      "alb.ingress.kubernetes.io/healthcheck-protocol"     = "HTTPS"
      "alb.ingress.kubernetes.io/healthcheck-path"         = "/${var.arcgis_enterprise_context}/rest/info/healthcheck"
      "alb.ingress.kubernetes.io/success-codes"            = "200-399"
      "alb.ingress.kubernetes.io/certificate-arn"          = var.ssl_certificate_arn
      "alb.ingress.kubernetes.io/ssl-policy"               = var.ssl_policy
      "alb.ingress.kubernetes.io/load-balancer-attributes" = "access_logs.s3.enabled=${var.enable_access_log},access_logs.s3.bucket=${data.aws_ssm_parameter.s3_logs.value}"
      "alb.ingress.kubernetes.io/wafv2-acl-arn"            = aws_wafv2_web_acl.arcgis_enterprise.arn
    }
  }

  spec {
    ingress_class_name = "alb"
    rule {
      host = var.ingress_fqdn
      http {
        path {
          path      = "/${var.arcgis_enterprise_context}"
          path_type = "Prefix"
          backend {
            service {
              name = "arcgis-ingress-nginx"
              port {
                number = 443
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_namespace.arcgis_enterprise
  ]
}

resource "aws_ssm_parameter" "alb_arn" {
  name        = "/arcgis/${var.enterprise_id}/${var.deployment_id}/alb/arn"
  type        = "String"
  value       = data.aws_lb.arcgis_enterprise_ingress.arn
  description = "ARN of the deployment's ALB"
}

resource "aws_ssm_parameter" "alb_dns_name" {
  name        = "/arcgis/${var.enterprise_id}/${var.deployment_id}/alb/dns-name"
  type        = "String"
  value       = data.aws_lb.arcgis_enterprise_ingress.dns_name
  description = "DNS name of the deployment's ingress load balancer"
}

resource "aws_ssm_parameter" "ingress_fqdn" {
  name        = "/arcgis/${var.enterprise_id}/${var.deployment_id}/ingress-fqdn"
  type        = "String"
  value       = var.ingress_fqdn
  description = "Fully qualified domain name of the ingress"
}

# Route53 private hosted zone for the ingress FQDN
resource "aws_route53_zone" "ingress_fqdn" {
  name = var.ingress_fqdn

  vpc {
    vpc_id = data.aws_ssm_parameter.vpc_id.value
  }
}

# Create Route 53 record for the Application Load Balancer 
resource "aws_route53_record" "ingress_fqdn" {
  zone_id = aws_route53_zone.ingress_fqdn.zone_id
  name    = "" # Apex domain name
  type    = "A"
  alias {
    name                   = data.aws_lb.arcgis_enterprise_ingress.dns_name
    zone_id                = data.aws_lb.arcgis_enterprise_ingress.zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "arcgis_enterprise" {
  count   = var.hosted_zone_id != null ? 1 : 0
  zone_id = var.hosted_zone_id
  name    = "${var.ingress_fqdn}."
  type    = "A"
  alias {
    name                   = data.aws_lb.arcgis_enterprise_ingress.dns_name
    zone_id                = data.aws_lb.arcgis_enterprise_ingress.zone_id
    evaluate_target_health = false
  }
}

module "monitoring" {
  source        = "./modules/monitoring"
  namespace     = var.deployment_id
  alb_arn       = data.aws_lb.arcgis_enterprise_ingress.arn
  sns_topic_arn = data.aws_ssm_parameter.sns_topic.value
  waf_log_group = aws_cloudwatch_log_group.waf_logs.name
}
