/**
 * # Terraform module dashboard
 * 
 * Terraform module dashboard creates AWS resources for the deployment monitoring subsystem:
 *
 * * CloudWatch alarms for unhealthy EC2 instances, 
 * * SNS topic used by the alarms, and
 * * CloudWatch dashboard. 
 *
 * The CloudWatch dashboard includes widgets for:
 *
 * * CloudWatch alarms,
 * * Healthy and unhealthy host count in the ALB target groups,
 * * CPU, memory, disk, and network utilization of the deployment's EC2 instances,
 * * EBS volume read and write bytes of the deployment EC2 instances,
 * * System and Chef log of the deployment EC2 instances.
 */

data "aws_region" "current" {}

data "aws_instances" "deployment_instances" {
  instance_tags = {
    ArcGISSiteId = var.site_id    
    ArcGISDeploymentId = var.deployment_id    
  }

   instance_state_names = ["running"]
}

data "aws_ebs_volumes" "deployment_volumes" {
  tags = {
    ArcGISSiteId = var.site_id    
    ArcGISDeploymentId = var.deployment_id    
  }
}

locals {
  alarms_widgets_y = 0
  alb_widgets_y = 3
  ec2_widgets_y = 17
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
            for alarm in aws_cloudwatch_metric_alarm.unhealthy_alb_instances : alarm.arn
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
          for tg_arn in var.target_group_arns : [ "AWS/ApplicationELB", "RequestCount", "LoadBalancer", trimprefix(split(":", var.alb_arn)[5], "loadbalancer/"), "TargetGroup", split(":", tg_arn)[5] ]
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
          for tg_arn in var.target_group_arns : [ "AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", trimprefix(split(":", var.alb_arn)[5], "loadbalancer/"), "TargetGroup", split(":", tg_arn)[5] ]
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
          for tg_arn in var.target_group_arns : [ "AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", trimprefix(split(":", var.alb_arn)[5], "loadbalancer/"), "TargetGroup", split(":", tg_arn)[5] ]
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
        title = "UnHealthy Hosts Count"
        metrics = [
          for tg_arn in var.target_group_arns : [ "AWS/ApplicationELB", "UnHealthyHostCount", "LoadBalancer", trimprefix(split(":", var.alb_arn)[5], "loadbalancer/"), "TargetGroup", split(":", tg_arn)[5] ]
        ]
        yAxis = {
          left = {
            min = 0
          }
        }
        period = 60
        stat   = "Maximum"
        region = data.aws_region.current.name
      }
    }
  ]

  ec2_widgets = [
    {
      type   = "metric"
      x      = 0
      y      = local.ec2_widgets_y
      width  = 12
      height = 6

      properties = {
        title  = "CPU Utilization"          
        metrics = [
          for id in data.aws_instances.deployment_instances.ids : [ "AWS/EC2", "CPUUtilization", "InstanceId", id ]
        ]
        yAxis = {
          left = {
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
        stat   = "Average"
        region = data.aws_region.current.name
      }
    },
    {
      type = "metric"
      x = 13
      y = local.ec2_widgets_y
      width = 12
      height = 6
      
      properties = {
        title = "Memory Available (bytes)"
        metrics = [
          for id in data.aws_instances.deployment_instances.ids : [ "CWAgent", "mem_available", "InstanceId", id ]
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
      type = "metric"
      x = 0
      y = local.ec2_widgets_y + 7
      width = 12
      height = 6
      
      properties = {
        title = "System Processes"
        metrics = [
          for id in data.aws_instances.deployment_instances.ids : [ "CWAgent", "processes_total", "InstanceId", id ]
        ]
        yAxis = {
          left = {
            min = 0
          }
        }
        period = 60
        stat   = "Maximum"
        region = data.aws_region.current.name
      }
    },
    {
      type = "metric"
      x = 13
      y = local.ec2_widgets_y + 7
      width = 12
      height = 6
      
      properties = {
        title = "Disk Free (megabytes)"
        metrics = [
          for id in data.aws_instances.deployment_instances.ids : [ "CWAgent", "disk_free", "InstanceId", id ]
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
      x = 0
      y = local.ec2_widgets_y + 14
      width = 12
      height = 6
      
      properties = {
        title = "EBS Volume Read (bytes)"
        metrics = [
          # for id in data.aws_ebs_volumes.deployment_volumes.ids : [ "AWS/EBS", "VolumeReadBytes", "VolumeId", id ]
          for id in data.aws_instances.deployment_instances.ids : [ "AWS/EC2", "EBSReadBytes", "InstanceId", id ]
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
      y = local.ec2_widgets_y + 14
      width = 12
      height = 6
      
      properties = {
        title = "EBS Volume Write (bytes)"
        metrics = [
          # for id in data.aws_ebs_volumes.deployment_volumes.ids : [ "AWS/EBS", "VolumeWriteBytes", "VolumeId", id ]
          for id in data.aws_instances.deployment_instances.ids : [ "AWS/EC2", "EBSWriteBytes", "InstanceId", id ]
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
      x = 0
      y = local.ec2_widgets_y + 21
      width = 12
      height = 6
      
      properties = {
        title = "Network In (bytes)"
        metrics = [
          for id in data.aws_instances.deployment_instances.ids : [ "AWS/EC2", "NetworkIn", "InstanceId", id ]
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
      x = 13
      y = local.ec2_widgets_y + 21
      width = 12
      height = 6
      
      properties = {
        title = "Network Out (bytes)"
        metrics = [
          for id in data.aws_instances.deployment_instances.ids : [ "AWS/EC2", "NetworkOut", "InstanceId", id ]
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
        title = "System Event Log"
        query = "SOURCE '${var.log_group_name}' | fields @timestamp, @logStream, @message | sort @timestamp desc | limit 20"
        region = data.aws_region.current.name
        stacked = false
        view = "table"
      }
    }
  ] 
}

resource "aws_sns_topic" "deployment_alarms" {
  name = var.deployment_id
}

resource "aws_ssm_parameter" "sns_topic" {
  name        = "/arcgis/${var.site_id}/${var.deployment_id}/sns-topic-arn"
  type        = "String"
  tier        = "Intelligent-Tiering"
  value       = aws_sns_topic.deployment_alarms.arn
  description = "ARN of SNS topic for deployment alarms"
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_alb_instances" {
  count                     = length(var.target_group_arns)
  alarm_name                = "UnHealthyHosts/${split(":", var.target_group_arns[count.index])[5]}"
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
    LoadBalancer = trimprefix(split(":", var.alb_arn)[5], "loadbalancer/")
    TargetGroup = split(":", var.target_group_arns[count.index])[5]
  }
}

resource "aws_cloudwatch_composite_alarm" "unhealthy_alb_targets" {
  alarm_description = "${var.deployment_id} deployment alarms"
  alarm_name        = "DeploymentAlarms/${var.deployment_id}"

  alarm_actions = [ aws_sns_topic.deployment_alarms.arn ]
  ok_actions    = [ aws_sns_topic.deployment_alarms.arn ]

  alarm_rule = join(" OR ", [
    for alarm in aws_cloudwatch_metric_alarm.unhealthy_alb_instances : "ALARM(${alarm.alarm_name})"
  ])
}

resource "aws_cloudwatch_dashboard" "dashboard" {
  dashboard_name = var.name

  dashboard_body = jsonencode({
    widgets = concat(local.alarms_widgets, local.alb_widgets, local.ec2_widgets, local.logs_widgets)
  })
}
