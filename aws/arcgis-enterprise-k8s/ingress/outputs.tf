output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value = kubernetes_ingress_v1.arcgis_enterprise.status.0.load_balancer.0.ingress.0.hostname
}