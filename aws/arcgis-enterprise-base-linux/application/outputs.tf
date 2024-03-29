output "arcgis_server_url" {
  description = "ArcGIS Server URL"
  value       = "https://${var.deployment_fqdn}/server"
}

output "arcgis_portal_url" {
  description = "Portal for ArcGIS URL"
  value       = "https://${var.deployment_fqdn}/portal"
}

output "arcgis_server_private_url" {
  description = "ArcGIS Server private URL"
  value       = "https://${var.deployment_fqdn}:6443/arcgis"
}

output "arcgis_portal_private_url" {
  description = "Portal for ArcGIS private URL"
  value       = "https://${var.deployment_fqdn}:7443/arcgis"
}
