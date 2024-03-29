output "arcgis_enterprise_manager_url" {
  description = "ArcGIS Enterprise Manager URL"
  value       = "https://${var.deployment_fqdn}/${var.arcgis_enterprise_context}/manager"
}

output "arcgis_enterprise_portal_url" {
  description = "ArcGIS Enterprise Portal URL"
  value       = "https://${var.deployment_fqdn}/${var.arcgis_enterprise_context}/home"
}
