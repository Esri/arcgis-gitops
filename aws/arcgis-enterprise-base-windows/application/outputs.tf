output "arcgis_server_url" {
  description = "ArcGIS Server URL"
  value       = "https://${var.domain_name}/server"
}

output "arcgis_portal_url" {
  description = "Portal for ArcGIS URL"
  value       = "https://${var.domain_name}/portal"
}

output "arcgis_server_private_url" {
  description = "ArcGIS Server private URL"
  value       = "https://${var.domain_name}:6443/arcgis"
}

output "arcgis_portal_private_url" {
  description = "Portal for ArcGIS private URL"
  value       = "https://${var.domain_name}:7443/arcgis"
}
