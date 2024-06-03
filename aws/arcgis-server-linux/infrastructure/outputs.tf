output "security_group_id" {
  description = "EC2 security group Id"
  value       = module.security_group.id
}

output "alb_dns_name" {
  description = "DNS name of the application load balancer"
  value       = aws_lb.alb.dns_name
}
