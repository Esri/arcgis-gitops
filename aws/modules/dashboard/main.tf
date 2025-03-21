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
 * * Healthy host count in the ALB target groups,
 * * CPU, memory, disk, and network utilization of the deployment's EC2 instances,
 * * System and Chef logs of the deployment EC2 instances.
 */

# Copyright 2024 Esri
#
# Licensed under the Apache License Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

data "aws_region" "current" {}

locals {
  alb_id           = trimprefix(split(":", var.alb_arn)[5], "loadbalancer/")
  alarms_widgets_y = 0
  alb_widgets_y    = 3
  ec2_widgets_y    = 17
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
            id         = "expr1"
            expression = "SELECT SUM(RequestCount) FROM SCHEMA(\"AWS/ApplicationELB\", LoadBalancer, TargetGroup) WHERE LoadBalancer='${local.alb_id}' GROUP BY TargetGroup"
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
            id         = "expr1"
            expression = "SELECT AVG(TargetResponseTime) FROM SCHEMA(\"AWS/ApplicationELB\", LoadBalancer, TargetGroup) WHERE LoadBalancer='${local.alb_id}' GROUP BY TargetGroup"
          }]
        ]
        yAxis = {
          left = {
            label     = "Seconds"
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
      x      = 0
      y      = local.alb_widgets_y + 7
      width  = 12
      height = 6

      properties = {
        title = "Healthy Hosts Count"
        metrics = [
          [{
            id         = "expr1"
            expression = "SELECT MIN(HealthyHostCount) FROM SCHEMA(\"AWS/ApplicationELB\", LoadBalancer, TargetGroup) WHERE LoadBalancer='${local.alb_id}' GROUP BY TargetGroup"
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
            id         = "expr1"
            expression = "SELECT SUM(HTTPCode_Target_5XX_Count) FROM SCHEMA(\"AWS/ApplicationELB\", LoadBalancer, TargetGroup) WHERE LoadBalancer='${local.alb_id}' GROUP BY TargetGroup"
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

  ec2_widgets_windows = [
    {
      type   = "metric"
      x      = 0
      y      = local.ec2_widgets_y
      width  = 12
      height = 6

      properties = {
        title = "CPU Utilization"
        metrics = [
          [{
            id         = "expr1"
            expression = "SELECT AVG(cpu_usage_active) FROM CWAgent WHERE SiteId='${var.site_id}' AND DeploymentId='${var.deployment_id}' GROUP BY InstanceId"
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
      y      = local.ec2_widgets_y
      width  = 12
      height = 6

      properties = {
        title = "Memory Available (bytes)"
        metrics = [
          [{
            id         = "expr1"
            expression = "SELECT AVG(mem_available) FROM CWAgent WHERE SiteId='${var.site_id}' AND DeploymentId='${var.deployment_id}' GROUP BY InstanceId"
          }]
        ]
        yAxis = {
          left = {
            label     = "Bytes"
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
      x      = 0
      y      = local.ec2_widgets_y + 7
      width  = 12
      height = 6

      properties = {
        title = "System Processes"
        metrics = [
          [{
            id         = "expr1"
            expression = "SELECT AVG(processes_total) FROM CWAgent WHERE SiteId='${var.site_id}' AND DeploymentId = '${var.deployment_id}' GROUP BY InstanceId"
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
      y      = local.ec2_widgets_y + 7
      width  = 12
      height = 6

      properties = {
        title = "Disk Free (bytes)"
        metrics = [
          [{
            id         = "expr1"
            expression = "SELECT SUM(disk_free_megabytes) FROM CWAgent WHERE SiteId='${var.site_id}' AND DeploymentId = '${var.deployment_id}' GROUP BY InstanceId"
            visible    = false
          }],
          [{
            id         = "expr2"
            expression = "expr1 * 1024 * 1024"
          }]
        ]
        yAxis = {
          left = {
            label     = "Bytes"
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
      x      = 0
      y      = local.ec2_widgets_y + 14
      width  = 12
      height = 6

      properties = {
        title = "Disk I/O Read (bytes/sec)"
        metrics = [
          [{
            id         = "expr1"
            expression = "SELECT SUM(diskio_read_bytes_sec) FROM CWAgent WHERE SiteId='${var.site_id}' AND DeploymentId = '${var.deployment_id}' GROUP BY InstanceId"
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
      y      = local.ec2_widgets_y + 14
      width  = 12
      height = 6

      properties = {
        title = "Disk I/O Write (bytes/sec)"
        metrics = [
          [{
            id         = "expr1"
            expression = "SELECT SUM(diskio_write_bytes_sec) FROM CWAgent WHERE SiteId='${var.site_id}' AND DeploymentId = '${var.deployment_id}' GROUP BY InstanceId"
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
      x      = 0
      y      = local.ec2_widgets_y + 21
      width  = 12
      height = 6

      properties = {
        title = "Network In (bytes/sec)"
        metrics = [
          [{
            id         = "expr1"
            expression = "SELECT SUM(net_bytes_recv_sec) FROM CWAgent WHERE SiteId='${var.site_id}' AND DeploymentId = '${var.deployment_id}' GROUP BY InstanceId"
            region     = data.aws_region.current.name            
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
      y      = local.ec2_widgets_y + 21
      width  = 12
      height = 6

      properties = {
        title = "Network Out (bytes/sec)"
        metrics = [
          [{
            id         = "expr1"
            expression = "SELECT SUM(net_bytes_sent_sec) FROM CWAgent WHERE SiteId='${var.site_id}' AND DeploymentId = '${var.deployment_id}' GROUP BY InstanceId"
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

  ec2_widgets_linux = [
    {
      type   = "metric"
      x      = 0
      y      = local.ec2_widgets_y
      width  = 12
      height = 6

      properties = {
        title = "CPU Utilization"
        metrics = [
          [{
            id         = "expr1"
            expression = "SELECT AVG(cpu_usage_active) FROM CWAgent WHERE SiteId='${var.site_id}' AND DeploymentId='${var.deployment_id}' AND cpu='cpu-total' GROUP BY InstanceId"
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
      y      = local.ec2_widgets_y
      width  = 12
      height = 6

      properties = {
        title = "Memory Available (bytes)"
        metrics = [
          [{
            id         = "expr1"
            expression = "SELECT AVG(mem_available) FROM CWAgent WHERE SiteId='${var.site_id}' AND DeploymentId='${var.deployment_id}' GROUP BY InstanceId"
          }]
        ]
        yAxis = {
          left = {
            label     = "Bytes"
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
      x      = 0
      y      = local.ec2_widgets_y + 7
      width  = 12
      height = 6

      properties = {
        title = "System Processes"
        metrics = [
          [{
            id         = "expr1"
            expression = "SELECT AVG(processes_total) FROM CWAgent WHERE SiteId='${var.site_id}' AND DeploymentId = '${var.deployment_id}' GROUP BY InstanceId"
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
      y      = local.ec2_widgets_y + 7
      width  = 12
      height = 6

      properties = {
        title = "Disk Free (bytes)"
        metrics = [
          [{
            id         = "expr1"
            expression = "SELECT AVG(disk_free) FROM CWAgent WHERE SiteId='${var.site_id}' AND DeploymentId = '${var.deployment_id}' GROUP BY InstanceId"
          }]
        ]
        yAxis = {
          left = {
            label     = "Bytes"
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
      x      = 0
      y      = local.ec2_widgets_y + 14
      width  = 12
      height = 6

      properties = {
        title = "Disk I/O Read (bytes/sec)"
        metrics = [
          [{
            visible    = false
            id         = "expr1"
            expression = "SELECT SUM(diskio_read_bytes) FROM CWAgent WHERE SiteId='${var.site_id}' AND DeploymentId = '${var.deployment_id}' GROUP BY InstanceId"
          }], [{
            expression = "expr1 / PERIOD(FIRST(expr1))"
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
      y      = local.ec2_widgets_y + 14
      width  = 12
      height = 6

      properties = {
        title = "Disk I/O Write (bytes/sec)"
        metrics = [
          [{
            id         = "expr1"
            expression = "SELECT SUM(diskio_write_bytes) FROM CWAgent WHERE SiteId='${var.site_id}' AND DeploymentId = '${var.deployment_id}' GROUP BY InstanceId"
            visible    = false
          }],
          [{
            expression = "expr1 / PERIOD(FIRST(expr1))"
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
      x      = 0
      y      = local.ec2_widgets_y + 21
      width  = 12
      height = 6

      properties = {
        title = "Network In (bytes/sec)"
        metrics = [
          [{
            id         = "expr1"
            expression = "SELECT SUM(net_bytes_recv) FROM CWAgent WHERE SiteId='${var.site_id}' AND DeploymentId = '${var.deployment_id}' GROUP BY InstanceId"
            visible    = false
          }],
          [{
            expression = "expr1 / PERIOD(FIRST(expr1))"
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
      y      = local.ec2_widgets_y + 21
      width  = 12
      height = 6

      properties = {
        title = "Network Out (bytes/sec)"
        metrics = [
          [{
            id         = "expr1"
            expression = "SELECT SUM(net_bytes_sent) FROM CWAgent WHERE SiteId='${var.site_id}' AND DeploymentId = '${var.deployment_id}' GROUP BY InstanceId"
            visible    = false
          }],
          [{
            expression = "expr1 / PERIOD(FIRST(expr1))"
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
        title   = "System Event Log"
        query   = "SOURCE '${var.log_group_name}' | fields @timestamp, @logStream, @message | sort @timestamp desc | limit 1000"
        region  = data.aws_region.current.name
        stacked = false
        view    = "table"
      }
    }
  ]
}

resource "aws_sns_topic" "deployment_alarms" {
  name = "${var.site_id}-${var.deployment_id}-alarms"
}

resource "aws_ssm_parameter" "sns_topic" {
  name        = "/arcgis/${var.site_id}/${var.deployment_id}/sns-topic-arn"
  type        = "String"
  tier        = "Intelligent-Tiering"
  value       = aws_sns_topic.deployment_alarms.arn
  description = "ARN of SNS topic for deployment alarms"
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_alb_instances" {
  alarm_name                = "${var.site_id}/${var.deployment_id}/UnHealthyHosts"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = 2
  threshold                 = 0
  alarm_description         = "Unhealthy instances in ALB target groups"
  insufficient_data_actions = []

  metric_query {
    id          = "e1"
    expression  = "SELECT MAX(UnHealthyHostCount) FROM SCHEMA(\"AWS/ApplicationELB\", LoadBalancer, TargetGroup) WHERE LoadBalancer='${local.alb_id}'"
    return_data = true
    period      = 60
  }

  alarm_actions = [aws_sns_topic.deployment_alarms.arn]
  ok_actions    = [aws_sns_topic.deployment_alarms.arn]
}

resource "aws_cloudwatch_dashboard" "dashboard" {
  dashboard_name = "${var.site_id}-${var.deployment_id}"

  dashboard_body = (var.platform == "windows" ?
    jsonencode({
      widgets = concat(local.alarms_widgets, local.alb_widgets, local.ec2_widgets_windows, local.logs_widgets)
    }) : 
    jsonencode({
      widgets = concat(local.alarms_widgets, local.alb_widgets, local.ec2_widgets_linux, local.logs_widgets)
    }))
}
