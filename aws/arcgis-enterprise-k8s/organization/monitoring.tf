resource "aws_sns_topic" "deployment_alarms" {
  name = var.deployment_id
}

data "aws_lb" "arcgis_enterprise_ingress" {
  tags = {
    "ingress.k8s.aws/stack" = "${var.deployment_id}/arcgis-enterprise-ingress"
  }
}

data "aws_lb_target_group" "arcgis_enterprise_ingress" {
  tags = {
    "ingress.k8s.aws/stack" = "${var.deployment_id}/arcgis-enterprise-ingress"
  }

  depends_on = [ 
    helm_release.arcgis_enterprise
  ]
}

locals {
  alb_arn = data.aws_lb.arcgis_enterprise_ingress.arn
  target_group_arns = [
    data.aws_lb_target_group.arcgis_enterprise_ingress.arn
  ]

  alarms_widgets_y = 0
  alb_widgets_y = 3
  ci_widgets_y = 17
  logs_widgets_y = 39

  alarms_widgets = [
    {
      type = "alarm"
      x = 0
      y = local.alarms_widgets_y
      width = 24
      height = 2

      properties = {
        title = "Alarms"
        alarms = [
            aws_cloudwatch_metric_alarm.unhealthy_alb_instances.arn
        ]
      }
    }
  ]

  alb_widgets = [
    {
      type = "metric"
      x = 0
      y = local.alb_widgets_y
      width = 12
      height = 6
      
      properties = {
        title = "Request Count"
        metrics = [
          for tg_arn in local.target_group_arns : [ "AWS/ApplicationELB", "RequestCount", "LoadBalancer", trimprefix(split(":", local.alb_arn)[5], "loadbalancer/"), "TargetGroup", split(":", tg_arn)[5] ]
        ]
        yAxis = {
          left = {
            min = 0
          }
        }
        period = 60
        stat   = "Sum"
        region = data.aws_region.current.name
      }
    },
    {
      type = "metric"
      x = 13
      y = local.alb_widgets_y
      width = 12
      height = 6
      
      properties = {
        title = "Response Time (seconds)"
        metrics = [
          for tg_arn in local.target_group_arns : [ "AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", trimprefix(split(":", local.alb_arn)[5], "loadbalancer/"), "TargetGroup", split(":", tg_arn)[5] ]
        ]
        yAxis = {
          left = {
            min = 0
          }
        }
        period = 60
        stat   = "Average"
        region = data.aws_region.current.name
      }
    },
    {
      type = "metric"
      x = 0
      y = local.alb_widgets_y + 7
      width = 12
      height = 6
      
      properties = {
        title = "Healthy Hosts Count"
        metrics = [
          for tg_arn in local.target_group_arns : [ "AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", trimprefix(split(":", local.alb_arn)[5], "loadbalancer/"), "TargetGroup", split(":", tg_arn)[5] ]
        ]
        yAxis = {
          left = {
            min = 0
          }
        }
        period = 60
        stat   = "Minimum"
        region = data.aws_region.current.name
      }
    },
    {
      type = "metric"
      x = 13
      y = local.alb_widgets_y + 7
      width = 12
      height = 6
      
      properties = {
        title = "Number of 500 HTTP response codes"
        metrics = [
          for tg_arn in local.target_group_arns : [ "AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", trimprefix(split(":", local.alb_arn)[5], "loadbalancer/"), "TargetGroup", split(":", tg_arn)[5] ]
        ]
        yAxis = {
          left = {
            min = 0
          }
        }
        period = 60
        stat   = "Sum"
        region = data.aws_region.current.name
      }
    }
  ]

  ci_widgets = [
    {
      type   = "metric"
      x      = 0
      y      = local.ci_widgets_y
      width  = 12
      height = 6
      properties = {
        title = "Pod CPU utilization (top 5)"
        metrics = [
          [ { "id": "expr1m0", "expression": "SELECT AVG(pod_cpu_utilization_over_pod_limit) FROM SCHEMA(ContainerInsights,ClusterName,FullPodName,Namespace,PodName) WHERE ClusterName='${var.site_id}' AND Namespace = '${var.deployment_id}' GROUP BY FullPodName ORDER BY MAX() DESC LIMIT 5" } ]
        ]
        yAxis = {
          left = {
            label = "Percent"
            showUnits = false
            min = 0
          }
        }
        annotations = {
          horizontal = [
            { value = 0 },
            { value = 100 }
          ]
        }        
        period = 60
        region = data.aws_region.current.name
      }
    },
    {
      type   = "metric"
      x      = 13
      y      = local.ci_widgets_y
      width  = 12
      height = 6
      properties = {
        title = "Pod memory utilization (top 5)"
        metrics = [
          [ { "id": "expr1m0", "expression": "SELECT AVG(pod_memory_utilization_over_pod_limit) FROM SCHEMA(ContainerInsights,ClusterName,FullPodName,Namespace,PodName) WHERE ClusterName='${var.site_id}' AND Namespace = '${var.deployment_id}' GROUP BY FullPodName ORDER BY MAX() DESC LIMIT 5" } ]
        ]
        yAxis = {
          left = {
            label = "Percent"
            showUnits = false
            min = 0
          }
        }
        annotations = {
          horizontal = [
            { value = 0 },
            { value = 100 }
          ]
        }        
        period = 60
        region = data.aws_region.current.name
      }
    },
    {
      type   = "metric"
      x      = 0
      y      = local.ci_widgets_y + 7
      width  = 12
      height = 6
      properties = {
        title = "Pod network received bytes (top 5)"
        metrics = [
          [ { "id": "expr1m0", "expression": "SELECT AVG(pod_network_rx_bytes) FROM SCHEMA(ContainerInsights,ClusterName,FullPodName,Namespace,PodName) WHERE ClusterName='${var.site_id}' AND Namespace = '${var.deployment_id}' GROUP BY FullPodName ORDER BY MAX() DESC LIMIT 5" } ]
        ]
        yAxis = {
          left = {
            label = "Bytes"
            showUnits = false
            min = 0
          }
        }
        period = 60
        region = data.aws_region.current.name
      }
    },
    {
      type   = "metric"
      x      = 13
      y      = local.ci_widgets_y + 7
      width  = 12
      height = 6
      properties = {
        title = "Pod network transmitted bytes (top 5)"
        metrics = [
          [ { "id": "expr1m0", "expression": "SELECT AVG(pod_network_tx_bytes) FROM SCHEMA(ContainerInsights,ClusterName,FullPodName,Namespace,PodName) WHERE ClusterName='${var.site_id}' AND Namespace = '${var.deployment_id}' GROUP BY FullPodName ORDER BY MAX() DESC LIMIT 5" } ]
        ]
        yAxis = {
          left = {
            label = "Bytes"
            showUnits = false
            min = 0
          }
        }
        period = 60
        region = data.aws_region.current.name
      }
    }
  ]

  logs_widgets = [
    {
      type = "log"
      x = 0
      y = local.logs_widgets_y
      width = 24
      height = 12
      properties = {
        title = "Container Logs"
        query = "SOURCE '/aws/containerinsights/${var.site_id}/application' | fields @timestamp, kubernetes.pod_name, log | filter kubernetes.namespace_name = '${var.deployment_id}' and kubernetes.container_name != 'filebeat' | sort @timestamp desc | limit 1000"
        region = data.aws_region.current.name
        stacked = false
        view = "table"
      }
    }
  ] 
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

resource "aws_sns_topic_subscription" "infrastructure_alarms" {
  topic_arn = aws_sns_topic.deployment_alarms.arn
  protocol  = "email"
  endpoint  = var.admin_email
}

resource "aws_cloudwatch_dashboard" "dashboard" {
  dashboard_name = var.deployment_id

  dashboard_body = jsonencode({
    widgets = concat(local.alarms_widgets, local.alb_widgets, local.ci_widgets, local.logs_widgets)
  })
}