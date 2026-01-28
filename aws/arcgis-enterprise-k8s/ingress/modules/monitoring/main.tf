/**
 * # Ingress Monitoring Terraform Module
 * 
 * The module creates Monitoring Subsystem for the ArcGIS Enterprise on Kubernetes cluster-level ingress that includes:
 *
 * * A CloudWatch alarm that monitors the ingress ALB target groups and post to the site alarms SNS topic if the number of unhealthy instances is nonzero.
 * * A CloudWatch dashboard that displays the CloudWatch alarm status, ALB metrics, and log of requests flagged by WAF rules.
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
  alb_id  = trimprefix(split(":", var.alb_arn)[5], "loadbalancer/")

  alarms_widgets_y = 0
  alb_widgets_y    = 3
  waf_widgets_y    = 17

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
        region = data.aws_region.current.region
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
        region = data.aws_region.current.region
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
        region = data.aws_region.current.region
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
        region = data.aws_region.current.region
      }
    }
  ]

  waf_widgets = [
    {
      type   = "log"
      x      = 0
      y      = local.waf_widgets_y
      width  = 24
      height = 12
      properties = {
        title         = "Requests Flagged by WAF"
        query         = "SOURCE '${var.waf_log_group}' | fields fromMillis(timestamp) as Timestamp, action as Action, httpRequest.host as Host, httpRequest.uri as Path, httpRequest.httpMethod as Method, httpRequest.clientIp as ClientIp, httpRequest.country as Country, terminatingRuleId as TerminatingRuleId, nonTerminatingMatchingRules.0.ruleId as NonTerminatingRuleId | filter terminatingRuleId != 'Default_Action' or ispresent(nonTerminatingMatchingRules.0.ruleId) | sort timestamp desc | limit 100"
        queryLanguage = "CWLI"
        queryBy       = "logGroupName"
        region = data.aws_region.current.region
        view   = "table"
      }
    }
  ]
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

  alarm_actions = [var.sns_topic_arn]
  ok_actions    = [var.sns_topic_arn]

  alarm_rule = join(" OR ", [
    "ALARM(${aws_cloudwatch_metric_alarm.unhealthy_alb_instances.alarm_name})"
  ])

  depends_on = [
    aws_cloudwatch_metric_alarm.unhealthy_alb_instances
  ]
}

resource "aws_cloudwatch_dashboard" "dashboard" {
  dashboard_name = "${var.namespace}-ingress"

  dashboard_body = jsonencode({
    widgets = concat(local.alarms_widgets, local.alb_widgets, local.waf_widgets)
  })
}
