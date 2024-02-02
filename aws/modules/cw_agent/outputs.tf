output "log_group_name" {
  description = "CloudWatch log group name"
  value = aws_cloudwatch_log_group.deployment.name
}
