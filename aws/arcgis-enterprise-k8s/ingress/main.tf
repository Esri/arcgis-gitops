/**
 * # Ingress Terraform Module for Base ArcGIS Enterprise on Kubernetes
 * 
 * This module provisions a Kubernetes namespace for ArcGIS Enterprise on 
 * Kubernetes deployment in Amazon Elastic Kubernetes Service (EKS) cluster and
 * a cluster-level ingress controller that routes traffic to the deployment.
 *
 * See: https://enterprise-k8s.arcgis.com/en/latest/deploy/use-a-cluster-level-ingress-controller-with-eks.htm
 *
 * If a Route 53 hosted zone ID is provided, a CNAME record is created in the hosted zone
 * that points the deployment's FQDN to the load balancer's DNS name.
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
    key = "arcgis-enterprise/aws/arcgis-enterprise-k8s/ingress.tfstate"
  }

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.26"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.22"
    }   
  }

  required_version = ">= 1.1.9"
}

provider "kubernetes" {
  config_path = "~/.kube/config"
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
    name = "arcgis-enterprise-ingress"
    annotations = {
      "alb.ingress.kubernetes.io/scheme" = var.internal_load_balancer ? "internal" : "internet-facing"
      "alb.ingress.kubernetes.io/target-type" = "ip"
      "alb.ingress.kubernetes.io/backend-protocol" = "HTTPS"
      "alb.ingress.kubernetes.io/listen-ports" = "[{\"HTTPS\":443}]"
      "alb.ingress.kubernetes.io/healthcheck-port" = "443"
      "alb.ingress.kubernetes.io/healthcheck-protocol" = "HTTPS"
      "alb.ingress.kubernetes.io/healthcheck-path" = "/${var.arcgis_enterprise_context}/rest/info/healthcheck"
      "alb.ingress.kubernetes.io/success-codes" = "200-399"
      "alb.ingress.kubernetes.io/certificate-arn" = var.ssl_certificate_arn
      "alb.ingress.kubernetes.io/ssl-policy" = var.ssl_policy
    }
  }

  spec {
    ingress_class_name  = "alb"
    rule {
      host = var.deployment_fqdn
      http {
        path {
          path = "/${var.arcgis_enterprise_context}"
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

resource "aws_route53_record" "arcgis_enterprise" {
  count = var.hosted_zone_id != null ? 1 : 0
  zone_id = var.hosted_zone_id
  name    = "${var.deployment_fqdn}."
  type    = "CNAME"
  ttl     = 300
  records = [kubernetes_ingress_v1.arcgis_enterprise.status.0.load_balancer.0.ingress.0.hostname]
}
