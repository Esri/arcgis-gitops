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

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.22"
    }
  }
}

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

      aggregation_dimensions = [
        ["InstanceId"]
      ]

      metrics_collected = {
        mem = {
          measurement                 = ["mem_available"]
          metrics_collection_interval = 60
        }
        disk = {
          resources = ["/"]
          measurement = [
            {
              name   = "free"
              rename = "disk_free"
              unit   = "Megabytes"
            }
          ]
          ignore_file_system_types = [
            "sysfs",
            "devtmpfs"
          ]
          metrics_collection_interval = 60
        }
        processes = {
          measurement = [
            {
              name = "processes_total"
              unit = "Count"
            }
          ]
          metrics_collection_interval = 60
        }
      }
    }

    logs = {
      logs_collected = {    
        files = {
          collect_list = [
            {
              file_path = "/var/log/messages"
              log_group_name = aws_cloudwatch_log_group.deployment.name
              log_stream_name = "{instance_id}-system"
              timestamp_format = "%b %-d %H:%M:%S"
            },
            {
              file_path = "/var/log/chef-run.log"
              log_group_name = aws_cloudwatch_log_group.deployment.name
              log_stream_name = "{instance_id}-chef"
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

      aggregation_dimensions = [
        ["InstanceId"]
      ]

      metrics_collected = {
        statsd = {}
        Memory = {
          measurement = [
            {
              name   = "Available Bytes"
              rename = "mem_available"
              unit   = "Bytes"
            }
          ]
          metrics_collection_interval = 60
        }
        LogicalDisk = {
          measurement = [
            {
              name   = "Free Megabytes"
              rename = "disk_free"
              unit   = "Megabytes"
            }
          ]
          resources = ["*"]
          metrics_collection_interval = 60
        }
        System = {
          measurement = [
            {
              name   = "Processes"
              rename = "processes_total"
              unit = "Count"
            }
          ]
          metrics_collection_interval = 60
        }
      }
    }
    logs = {
      logs_collected = {
        windows_events = {
          collect_list = [
            {
              event_name = "System"
              event_format = "text"
              event_levels = [ "INFORMATION", "ERROR" ]
              log_group_name = aws_cloudwatch_log_group.deployment.name
              log_stream_name = "{instance_id}-system"
            }
          ]
        }
        files = {
          collect_list = [
            {
              file_path = "C:\\chef\\chef-run.log"
              encoding = "utf-16"
              log_group_name = aws_cloudwatch_log_group.deployment.name
              log_stream_name = "{instance_id}-chef"
              timestamp_format = "%Y-%m-%dT%H:%M:%S"
            }
          ]
        }

      }
    }
  })
}

resource "aws_cloudwatch_log_group" "deployment" {
  name_prefix = var.deployment_id
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
    command = "python -m ssm_cloudwatch_config -s ${var.site_id} -d ${var.deployment_id} -p ${aws_ssm_parameter.cloudwatch_agent_config.name} -b ${nonsensitive(data.aws_ssm_parameter.output_s3_bucket.value)}"
  }

  depends_on = [
    aws_ssm_parameter.cloudwatch_agent_config
  ]
}
