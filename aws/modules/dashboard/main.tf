/**
 * # Terraform module dashboard
 * 
 * Terraform module dashboard creates AWS resources for the deployment monitoring subsystem.
 *
 * The CloudWatch dashboard includes widgets for:
 *
 * * CPU, memory, disk, and network utilization of the deployment's EC2 instances,
 * * System and Chef logs of the deployment EC2 instances.
 */

# Copyright 2026 Esri
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
  ec2_widgets_y    = 0
  logs_widgets_y   = 28

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
        region = data.aws_region.current.region
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
        region = data.aws_region.current.region
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
        region = data.aws_region.current.region
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
        region = data.aws_region.current.region
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
        region = data.aws_region.current.region
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
        region = data.aws_region.current.region
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
            region     = data.aws_region.current.region            
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
        region = data.aws_region.current.region
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
        region = data.aws_region.current.region
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
        region = data.aws_region.current.region
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
        region = data.aws_region.current.region
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
        region = data.aws_region.current.region
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
        region = data.aws_region.current.region
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
        region = data.aws_region.current.region
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
        region = data.aws_region.current.region
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
        region = data.aws_region.current.region
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
        region = data.aws_region.current.region
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
        region  = data.aws_region.current.region
        stacked = false
        view    = "table"
      }
    }
  ]
}

resource "aws_cloudwatch_dashboard" "dashboard" {
  dashboard_name = "${var.site_id}-${var.deployment_id}"

  dashboard_body = (var.platform == "windows" ?
    jsonencode({
      widgets = concat(local.ec2_widgets_windows, local.logs_widgets)
    }) : 
    jsonencode({
      widgets = concat(local.ec2_widgets_linux, local.logs_widgets)
    }))
}
