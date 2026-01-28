/**
 * # Terraform module monitoring
 * 
 * The module creates Monitoring Subsystem for the ArcGIS Enterprise on Kubernetes deployment.
 *
 * The Monitoring Subsystem consists of:
 *
 * * A CloudWatch alarm that monitors the ingress ALB target groups and post to the SNS topic if the number of unhealthy instances in nonzero.
 * * A CloudWatch dashboard that displays the CloudWatch alerts, metrics, and container logs of the deployment.
 */

# Copyright 2024-2026 Esri
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
  ci_widgets_y     = 0
  logs_widgets_y   = 22

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
        region = data.aws_region.current.region
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
        region = data.aws_region.current.region
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
        region = data.aws_region.current.region
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
        title   = "Container Logs"
        query   = "SOURCE '/aws/containerinsights/${var.cluster_name}/application' | fields @timestamp, kubernetes.pod_name, log | filter kubernetes.namespace_name = '${var.namespace}' and kubernetes.container_name != 'filebeat' | sort @timestamp desc | limit 1000"
        region  = data.aws_region.current.region
        stacked = false
        view    = "table"
      }
    }
  ]
}

resource "aws_cloudwatch_dashboard" "dashboard" {
  dashboard_name = "${var.namespace}-organization"

  dashboard_body = jsonencode({
    widgets = concat(local.ci_widgets, local.logs_widgets)
  })
}
