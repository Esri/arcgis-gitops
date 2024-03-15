output "security_group_id" {
  description = "EC2 security group Id"
  value       = module.security_group.id
}

output "alb_dns_name" {
  description = "DNS name of application load balancer"
  value       = aws_lb.alb.dns_name
}

output "alb_arn" {
  description = "ARN of appication load balancer"
  value       = aws_lb.alb.arn
}



