output "vpc_id" {
  description = "VPC Id of ArcGIS Enterprise site"
  value       = aws_vpc.vpc.id
}
