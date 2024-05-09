output "sns_topic_arn" {
  description = "The ARN of the SNS topic that will be used for monitoring alerts"
  value       = aws_sns_topic.deployment_alarms.arn
}
