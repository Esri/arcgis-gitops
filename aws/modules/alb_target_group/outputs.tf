output "name" {
  description = "Application load balancer target group name"
  value       = aws_lb_target_group.target_group.name
}

output "arn" {
  description = "Target group ARN"
  value = aws_lb_target_group.target_group.arn
}
