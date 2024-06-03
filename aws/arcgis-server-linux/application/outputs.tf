output "arcgis_server_url" {
  description = "ArcGIS Server URL"
  value       = "https://${var.deployment_fqdn}/arcgis"
}

output "arcgis_server_private_url" {
  description = "ArcGIS Server private URL"
  value       = "https://${var.deployment_fqdn}:6443/arcgis"
}

