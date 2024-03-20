output "vpc_id" {
  description = "VPC Id of ArcGIS Enterprise site"
  value       = aws_vpc.vpc.id
}

output "public_subnets" {
  description = "Public subnets"
  value       = aws_subnet.public_subnets.*.id
}

output "private_subnets" {
  description = "Private subnets"
  value       = aws_subnet.private_subnets.*.id
}

output "isolated_subnets" {
  description = "Isolated subnets"
  value       = aws_subnet.isolated_subnets.*.id
}

