/**
 * # cw_agent terraform module
 * 
 * Terraform module cw_agent configures CloudWatch agents on the deployment's EC2 instances.
 * 
 * The module also creates a CloudWatch log group used by the CloudWatch agents to send logs to.
 *
 * The module uses ssm_cloudwatch_config.py script to run AmazonCloudWatch-ManageAgent SSM command on the deployment's EC2 instances in specific roles.
 *
 * ## Requirements
 *
 * The S3 bucket for the SSM command output is retrieved from "/arcgis/{var.site_id}/s3/logs" SSM parameter.
 *
 * On the machine where Terraform is executed:
 *
 * * Python 3.8 or later with [AWS SDK for Python (Boto3)](https://aws.amazon.com/sdk-for-python/) package must be installed
 * * Path to aws/scripts directory must be added to PYTHONPATH
 * * AWS credentials must be configured
 * * AWS region must be specified by AWS_DEFAULT_REGION environment variable
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

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.22"
    }
  }
}

data "aws_region" "current" {}

data "aws_ssm_parameter" "output_s3_bucket" {
  name = "/arcgis/${var.site_id}/s3/logs"
}

locals {
  linux_agent_config = jsonencode({
    agent = {
      metrics_collection_interval = 60
      run_as_user                 = "root"
    }

    metrics = {
      append_dimensions = {
        InstanceId = "$${aws:InstanceId}"
      }

      metrics_collected = {
        cpu = {
          measurement                 = ["cpu_usage_active"]
          metrics_collection_interval = 60
          append_dimensions = {
            SiteId       = var.site_id
            DeploymentId = var.deployment_id
          }
        }
        mem = {
          measurement                 = ["mem_available"]
          metrics_collection_interval = 60
          append_dimensions = {
            SiteId       = var.site_id
            DeploymentId = var.deployment_id
          }
        }
        disk = {
          resources = ["/"]
          measurement = [
            {
              name   = "free"
              rename = "disk_free"
              unit   = "Bytes"
            }
          ]
          ignore_file_system_types = [
            "sysfs",
            "devtmpfs"
          ]
          metrics_collection_interval = 60
          append_dimensions = {
            SiteId       = var.site_id
            DeploymentId = var.deployment_id
          }
        }
        diskio = {
          measurement                 = ["diskio_write_bytes", "diskio_read_bytes"]
          metrics_collection_interval = 60
          append_dimensions = {
            SiteId       = var.site_id
            DeploymentId = var.deployment_id
          }
        }
        net = {
          measurement                 = ["net_bytes_recv", "net_bytes_sent"]
          metrics_collection_interval = 60
          append_dimensions = {
            SiteId       = var.site_id
            DeploymentId = var.deployment_id
          }
        }
        processes = {
          measurement                 = ["processes_total"]
          metrics_collection_interval = 60
          append_dimensions = {
            SiteId       = var.site_id
            DeploymentId = var.deployment_id
          }
        }
      }
    }

    logs = {
      logs_collected = {
        files = {
          collect_list = [
            {
              file_path        = "/var/log/messages"
              log_group_name   = aws_cloudwatch_log_group.deployment.name
              log_stream_name  = "{instance_id}-system"
              timestamp_format = "%b %-d %H:%M:%S"
            },
            {
              file_path        = "/var/log/chef-run.log"
              log_group_name   = aws_cloudwatch_log_group.deployment.name
              log_stream_name  = "{instance_id}-chef"
              timestamp_format = "%Y-%m-%dT%H:%M:%S"
            }
          ]
        }
      }
    }
  })

  windows_agent_config = jsonencode({
    agent = {
      metrics_collection_interval = 60
      run_as_user                 = "cwagent"
    }

    metrics = {
      append_dimensions = {
        InstanceId = "$${aws:InstanceId}"
      }

      # aggregation_dimensions = [
      #   ["InstanceId"]
      # ]

      metrics_collected = {
        statsd = {}
        Processor = {
          resources = ["*"]
          measurement = [
            {
              name   = "% Processor Time"
              rename = "cpu_usage_active"
              unit   = "Percent"
            }
          ]
          metrics_collection_interval = 60
          append_dimensions = {
            SiteId       = var.site_id
            DeploymentId = var.deployment_id
          }
        }
        Memory = {
          measurement = [
            {
              name   = "Available Bytes"
              rename = "mem_available"
              unit   = "Bytes"
            }
          ]
          metrics_collection_interval = 60
          append_dimensions = {
            SiteId       = var.site_id
            DeploymentId = var.deployment_id
          }
        }
        LogicalDisk = {
          measurement = [
            {
              name   = "Free Megabytes"
              rename = "disk_free_megabytes"
              unit   = "Megabytes"
            },
            {
              name   = "Disk Read Bytes/sec"
              rename = "diskio_read_bytes_sec"
              unit   = "Bytes/Second"
            },
            {
              name   = "Disk Write Bytes/sec"
              rename = "diskio_write_bytes_sec"
              unit   = "Bytes/Second"
            }
          ]
          resources                   = ["C:"]
          metrics_collection_interval = 60
          append_dimensions = {
            SiteId       = var.site_id
            DeploymentId = var.deployment_id
          }
        }
        "Network Interface" = {
          measurement = [
            {
              name   = "Bytes Received/sec"
              rename = "net_bytes_recv_sec"
              unit   = "Bytes/Second"
            },
            {
              name   = "Bytes Sent/sec"
              rename = "net_bytes_sent_sec"
              unit   = "Bytes/Second"
            }
          ]
          resources                   = ["*"]
          metrics_collection_interval = 60
          append_dimensions = {
            SiteId       = var.site_id
            DeploymentId = var.deployment_id
          }
        }
        System = {
          measurement = [
            {
              name   = "Processes"
              rename = "processes_total"
              unit   = "Count"
            }
          ]
          metrics_collection_interval = 60
          append_dimensions = {
            SiteId       = var.site_id
            DeploymentId = var.deployment_id
          }
        }
      }
    }
    logs = {
      logs_collected = {
        windows_events = {
          collect_list = [
            {
              event_name      = "System"
              event_format    = "text"
              event_levels    = ["INFORMATION", "ERROR"]
              log_group_name  = aws_cloudwatch_log_group.deployment.name
              log_stream_name = "{instance_id}-system"
            }
          ]
        }
        files = {
          collect_list = [
            {
              file_path        = "C:\\chef\\chef-run.log"
              encoding         = "utf-16"
              log_group_name   = aws_cloudwatch_log_group.deployment.name
              log_stream_name  = "{instance_id}-chef"
              timestamp_format = "%Y-%m-%dT%H:%M:%S"
            }
          ]
        }

      }
    }
  })
}

resource "aws_cloudwatch_log_group" "deployment" {
  name_prefix       = var.deployment_id
  retention_in_days = 7
}

resource "aws_ssm_parameter" "cloudwatch_agent_config" {
  name        = "/arcgis/${var.site_id}/monitoring/${var.deployment_id}/cloudwatch/config"
  type        = "String"
  value       = startswith(var.platform, "windows") ? local.windows_agent_config : local.linux_agent_config
  description = "CloudWatch agent configuration"
}

resource "null_resource" "ssm_cloudwatch_config" {
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    environment = {
      AWS_DEFAULT_REGION = data.aws_region.current.name
    }

    command = "python -m ssm_cloudwatch_config -s ${var.site_id} -d ${var.deployment_id} -p ${aws_ssm_parameter.cloudwatch_agent_config.name} -b ${nonsensitive(data.aws_ssm_parameter.output_s3_bucket.value)}"
  }

  depends_on = [
    aws_ssm_parameter.cloudwatch_agent_config
  ]
}
