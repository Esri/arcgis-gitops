/**
 * # Terraform module monitoring
 * 
 * The module creates Monitoring Subsystem for the ArcGIS Enterprise on Kubernetes deployment.
 *
 * The Monitoring Subsystem consists of:
 * An SNS topic with a subscription for the primary site administrator.
 * A CloudWatch alarm that monitors the ingress ALB target groups and post to the SNS topic if the number of unhealthy instances in nonzero.
 * A CloudWatch dashboard that displays the CloudWatch alerts, metrics, and container logs of the deployment.
 */


data "aws_region" "current" {}

data "aws_lb" "arcgis_enterprise_ingress" {
  tags = {
    "ingress.k8s.aws/stack" = "${var.namespace}/arcgis-enterprise-ingress"
  }
}

locals {
  alb_arn = data.aws_lb.arcgis_enterprise_ingress.arn
  alb_id  = trimprefix(split(":", local.alb_arn)[5], "loadbalancer/")

  alarms_widgets_y = 0
  alb_widgets_y    = 3
  ci_widgets_y     = 17
  logs_widgets_y   = 39

  alarms_widgets = [
    {
      type   = "alarm"
      x      = 0
      y      = local.alarms_widgets_y
      width  = 24
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
      type   = "metric"
      x      = 0
      y      = local.alb_widgets_y
      width  = 12
      height = 6

      properties = {
        title = "Request Count"
        metrics = [
          [{ 
            id = "expr1"
            expression = "SELECT SUM(RequestCount) FROM SCHEMA(\"AWS/ApplicationELB\", LoadBalancer, TargetGroup) WHERE LoadBalancer='${local.alb_id}' GROUP BY LoadBalancer LIMIT 5" 
          }]
        ]
        yAxis = {
          left = {
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
      y      = local.alb_widgets_y
      width  = 12
      height = 6

      properties = {
        title = "Response Time (seconds)"
        metrics = [
          [{
            id = "expr1"
            expression = "SELECT AVG(TargetResponseTime) FROM SCHEMA(\"AWS/ApplicationELB\", LoadBalancer, TargetGroup) WHERE LoadBalancer='${local.alb_id}' GROUP BY LoadBalancer LIMIT 5"
          }]
        ]
        yAxis = {
          left = {
            label = "Seconds"
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
      x      = 0
      y      = local.alb_widgets_y + 7
      width  = 12
      height = 6

      properties = {
        title = "Healthy Hosts Count"
        metrics = [
          [{
            id = "expr1"
            expression = "SELECT MIN(HealthyHostCount) FROM SCHEMA(\"AWS/ApplicationELB\", LoadBalancer, TargetGroup) WHERE LoadBalancer='${local.alb_id}' GROUP BY LoadBalancer LIMIT 5"
          }]
        ]
        yAxis = {
          left = {
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
      y      = local.alb_widgets_y + 7
      width  = 12
      height = 6

      properties = {
        title = "Number of 500 HTTP response codes"
        metrics = [
          [{
            id = "expr1"
            expression = "SELECT SUM(HTTPCode_Target_5XX_Count) FROM SCHEMA(\"AWS/ApplicationELB\", LoadBalancer, TargetGroup) WHERE LoadBalancer='${local.alb_id}' GROUP BY LoadBalancer LIMIT 5" 
          }]
        ]
        yAxis = {
          left = {
            min = 0
          }
        }
        period = 60
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
          [{
            id = "expr1"
            expression = "SELECT AVG(pod_cpu_utilization_over_pod_limit) FROM SCHEMA(ContainerInsights,ClusterName,FullPodName,Namespace,PodName) WHERE ClusterName='${var.cluster_name}' AND Namespace = '${var.namespace}' GROUP BY FullPodName ORDER BY MAX() DESC LIMIT 5"
          }]
        ]
        yAxis = {
          left = {
            label     = "Percent"
            showUnits = false
            min       = 0
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
          [{
            id = "expr1"
            expression = "SELECT AVG(pod_memory_utilization_over_pod_limit) FROM SCHEMA(ContainerInsights,ClusterName,FullPodName,Namespace,PodName) WHERE ClusterName='${var.cluster_name}' AND Namespace = '${var.namespace}' GROUP BY FullPodName ORDER BY MAX() DESC LIMIT 5"
          }]
        ]
        yAxis = {
          left = {
            label     = "Percent"
            showUnits = false
            min       = 0
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
          [{
            id = "expr1"
            expression = "SELECT AVG(pod_network_rx_bytes) FROM SCHEMA(ContainerInsights,ClusterName,FullPodName,Namespace,PodName) WHERE ClusterName='${var.cluster_name}' AND Namespace = '${var.namespace}' GROUP BY FullPodName ORDER BY MAX() DESC LIMIT 5"
          }]
        ]
        yAxis = {
          left = {
            label     = "Bytes/sec"
            showUnits = false
            min       = 0
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
          [{
            id = "expr1"
            expression = "SELECT AVG(pod_network_tx_bytes) FROM SCHEMA(ContainerInsights,ClusterName,FullPodName,Namespace,PodName) WHERE ClusterName='${var.cluster_name}' AND Namespace = '${var.namespace}' GROUP BY FullPodName ORDER BY MAX() DESC LIMIT 5"
          }]
        ]
        yAxis = {
          left = {
            label     = "Bytes/sec"
            showUnits = false
            min       = 0
          }
        }
        period = 60
        region = data.aws_region.current.name
      }
    }
  ]

  logs_widgets = [
    {
      type   = "log"
      x      = 0
      y      = local.logs_widgets_y
      width  = 24
      height = 12
      properties = {
        title   = "Container Logs"
        query   = "SOURCE '/aws/containerinsights/${var.cluster_name}/application' | fields @timestamp, kubernetes.pod_name, log | filter kubernetes.namespace_name = '${var.namespace}' and kubernetes.container_name != 'filebeat' | sort @timestamp desc | limit 1000"
        region  = data.aws_region.current.name
        stacked = false
        view    = "table"
      }
    }
  ]
}

resource "aws_sns_topic" "deployment_alarms" {
  name = var.namespace
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_alb_instances" {
  alarm_name                = "UnHealthyHosts/${var.namespace}"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = 2
  threshold                 = 0
  alarm_description         = "Unhealthy instances in ALB target group"
  insufficient_data_actions = []

  metric_query {
    id          = "e1"
    expression  = "SELECT MAX(UnHealthyHostCount) FROM SCHEMA(\"AWS/ApplicationELB\", LoadBalancer, TargetGroup) WHERE LoadBalancer='${local.alb_id}'"
    return_data = true
    period      = 60
  }
}

resource "aws_cloudwatch_composite_alarm" "unhealthy_alb_targets" {
  alarm_description = "${var.namespace} deployment alarms"
  alarm_name        = "DeploymentAlarms/${var.namespace}"

  alarm_actions = [aws_sns_topic.deployment_alarms.arn]
  ok_actions    = [aws_sns_topic.deployment_alarms.arn]

  alarm_rule = join(" OR ", [
    "ALARM(${aws_cloudwatch_metric_alarm.unhealthy_alb_instances.alarm_name})"
  ])

  depends_on = [
    aws_cloudwatch_metric_alarm.unhealthy_alb_instances
  ]
}

resource "aws_sns_topic_subscription" "infrastructure_alarms" {
  topic_arn = aws_sns_topic.deployment_alarms.arn
  protocol  = "email"
  endpoint  = var.admin_email
}

resource "aws_cloudwatch_dashboard" "dashboard" {
  dashboard_name = var.namespace

  dashboard_body = jsonencode({
    widgets = concat(local.alarms_widgets, local.alb_widgets, local.ci_widgets, local.logs_widgets)
  })
}
