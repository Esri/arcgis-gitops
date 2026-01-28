/**
 * # Ingress Terraform Module for Base ArcGIS Enterprise on Kubernetes
 * 
 * This module provisions a Kubernetes namespace for ArcGIS Enterprise on 
 * Kubernetes deployment in Amazon Elastic Kubernetes Service (EKS) cluster and
 * an ingress resource that routes traffic to the deployment.
 *
 * See: https://enterprise-k8s.arcgis.com/en/latest/deploy/use-a-cluster-level-ingress-controller-with-eks.htm
 *
 * The module creates a Web Application Firewall (WAF) Web ACL and associates it with the ingress Application Load Balancer.
 * The Web ACL is configured with a set of managed rules to protect the load balancer from common web exploits.
 * The WAF mode can be set either to "detect" (default) or "protect". 
 * In "detect" mode, the WAF only counts and logs the requests that match the rules,
 * while in "protect" mode, the WAF blocks the requests.
 *
 * If enable_access_log is set to true, access logging is enabled for the load balancer. The access logs are stored
 * in the site's logs S3 bucket specified by the "/arcgis/${var.site_id}/s3/logs" SSM parameter.
 *
 * If a Route 53 hosted zone ID is provided, an alias record is created in the hosted zone
 * that points the deployment's FQDN to the load balancer's DNS name. The DNS name is also stored in 
 * "/arcgis/${var.site_id}/${var.deployment_id}/alb/dns-name" SSM parameter.
 *
 * The module also creates a private Route 53 hosted zone for the deployment FQDN and an alias record 
 * in the hosted zone for the load balancer DNS name.
 * This makes the deployment FQDN always addressable from the VPC subnets. 
 *
 * The module creates a monitoring subsystem for the ingress that includes:
 *
 * * A CloudWatch alarm that monitors the health of ingress ALB target groups and posts to the site alarms SNS topic if the number of unhealthy instances is nonzero
 * * A CloudWatch log group for AWS WAF logs
 * * A CloudWatch dashboard that displays the CloudWatch alarm status, the ALB metrics, and the log of requests flagged by WAF rules
 * 
 * ## Requirements
 * 
 * On the machine where Terraform is executed:
 * 
 * * AWS credentials must be configured.
 * * EKS cluster configuration information must be provided in ~/.kube/config file.
 *
 * ## SSM Parameters
 *
 * The module reads the following SSM parameters: 
 *
 * | SSM parameter name | Description |
 * |--------------------|-------------|
 * | /arcgis/${var.site_id}/s3/logs | S3 bucket used by deployments to store logs |
 * | /arcgis/${var.site_id}/sns-topics/site-alarms | Site alarms SNS topic ARN |
 * | /arcgis/${var.site_id}/vpc/id | VPC ID |
 *
 * The module writes the following SSM parameters:
 *
 * | SSM parameter name | Description |
 * |--------------------|-------------|
 * | /arcgis/${var.site_id}/${var.deployment_id}/alb/arn | ARN of the application load balancer | 
 * | /arcgis/${var.site_id}/${var.deployment_id}/alb/dns-name | DNS name of the application load balancer |
 * | /arcgis/${var.site_id}/${var.deployment_id}/deployment-fqdn | Fully qualified domain name of the site ingress |
 */

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
      ArcGISSiteId       = var.site_id
      ArcGISDeploymentId = var.deployment_id
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

data "aws_ssm_parameter" "s3_logs" {
  name = "/arcgis/${var.site_id}/s3/logs"
}

data "aws_ssm_parameter" "sns_topic" {
  name = "/arcgis/${var.site_id}/sns-topics/site-alarms"
}

data "aws_ssm_parameter" "vpc_id" {
  name = "/arcgis/${var.site_id}/vpc/id"
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
      host = var.deployment_fqdn
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
  name        = "/arcgis/${var.site_id}/${var.deployment_id}/alb/arn"
  type        = "String"
  value       = data.aws_lb.arcgis_enterprise_ingress.arn
  description = "ARN of the deployment's ALB"
}

resource "aws_ssm_parameter" "alb_dns_name" {
  name        = "/arcgis/${var.site_id}/${var.deployment_id}/alb/dns-name"
  type        = "String"
  value       = data.aws_lb.arcgis_enterprise_ingress.dns_name
  description = "DNS name of the deployment's ingress load balancer"
}

resource "aws_ssm_parameter" "deployment_fqdn" {
  name        = "/arcgis/${var.site_id}/${var.deployment_id}/deployment-fqdn"
  type        = "String"
  value       = var.deployment_fqdn
  description = "Fully qualified domain name of the deployment"
}

# Route53 private hosted zone for the deployment FQDN
resource "aws_route53_zone" "deployment_fqdn" {
  name = var.deployment_fqdn

  vpc {
    vpc_id = data.aws_ssm_parameter.vpc_id.value
  }
}

# Create Route 53 record for the Application Load Balancer 
resource "aws_route53_record" "deployment_fqdn" {
  zone_id = aws_route53_zone.deployment_fqdn.zone_id
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
  name    = "${var.deployment_fqdn}."
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
