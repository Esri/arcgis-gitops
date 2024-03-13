/**
 * # Ingress Terraform Module for Base ArcGIS Enterprise on Kubernetes
 * 
 * This module provisions a Kubernetes namespace for ArcGIS Enterprise on 
 * Kubernetes deployment in Amazon Elastic Kubernetes Service (EKS) cluster and
 * a cluster-level ingress controller that routes traffic to the deployment.
 *
 * See: https://enterprise-k8s.arcgis.com/en/latest/deploy/use-a-cluster-level-ingress-controller-with-eks.htm
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
    key = "arcgis-enterprise/aws/arcgis-enterprise-k8s/ingress.tfstate"
  }

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.26"
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
  }
}

resource "kubernetes_ingress_v1" "arcgis_enterprise" {
  wait_for_load_balancer = true
  metadata {
    namespace = var.deployment_id
    name = "arcgis-enterprise-ingress"
    annotations = {
      "alb.ingress.kubernetes.io/scheme" = var.scheme
      "alb.ingress.kubernetes.io/target-type" = "ip"
      "alb.ingress.kubernetes.io/backend-protocol" = "HTTPS"
      "alb.ingress.kubernetes.io/listen-ports" = "[{\"HTTPS\":443}]"
      "alb.ingress.kubernetes.io/healthcheck-port" = "443"
      "alb.ingress.kubernetes.io/healthcheck-protocol" = "HTTPS"
      "alb.ingress.kubernetes.io/healthcheck-path" = "/${var.arcgis_enterprise_context}/admin"
      "alb.ingress.kubernetes.io/success-codes" = "200-399"
      "alb.ingress.kubernetes.io/certificate-arn" = var.ssl_certificate_arn
      "alb.ingress.kubernetes.io/ssl-policy" = var.ssl_policy
    }
  }

  spec {
    ingress_class_name  = "alb"
    rule {
      host = var.arcgis_enterprise_fqdn
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