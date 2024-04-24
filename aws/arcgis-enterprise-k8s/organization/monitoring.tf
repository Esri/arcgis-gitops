resource "aws_sns_topic" "deployment_alarms" {
  name = var.deployment_id
}

data "aws_lb" "arcgis_enterprise_ingress" {
  tags = {
    "key"   = "ingress.k8s.aws/stack"
    "value" = "${var.deployment_id}/arcgis-enterprise-ingress"
  }
}

data "aws_lb_target_group" "arcgis_enterprise_ingress" {
  tags = {
    "key"   = "ingress.k8s.aws/stack"
    "value" = "${var.deployment_id}/arcgis-enterprise-ingress"
  }
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_alb_instances" {
  alarm_name                = "UnHealthyHosts/${split(":", data.aws_lb_target_group.arcgis_enterprise_ingress.arn)[5]}"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = 2
  metric_name               = "UnHealthyHostCount"
  namespace                 = "AWS/ApplicationELB"
  period                    = 60
  statistic                 = "Maximum"
  threshold                 = 0
  alarm_description         = "Unhealthy instances in ALB target group"
  insufficient_data_actions = []

  dimensions = {
    LoadBalancer = trimprefix(split(":", data.aws_lb.arcgis_enterprise_ingress.arn)[5], "loadbalancer/")
    TargetGroup  = split(":", data.aws_lb_target_group.arcgis_enterprise_ingress.arn)[5]
  }
}

resource "aws_cloudwatch_composite_alarm" "unhealthy_alb_targets" {
  alarm_description = "${var.deployment_id} deployment alarms"
  alarm_name        = "DeploymentAlarms/${var.deployment_id}"

  alarm_actions = [aws_sns_topic.deployment_alarms.arn]
  ok_actions    = [aws_sns_topic.deployment_alarms.arn]

  alarm_rule = join(" OR ", [
    "ALARM(${aws_cloudwatch_metric_alarm.unhealthy_alb_instances.alarm_name})"
  ])
}
