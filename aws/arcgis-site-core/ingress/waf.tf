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

resource "aws_cloudwatch_log_group" "waf_logs" {
  name              = "aws-waf-logs-${var.site_id}-${var.deployment_id}"
  retention_in_days = 30
}

resource "aws_wafv2_web_acl" "arcgis_enterprise" {
  name        = "${var.site_id}-${var.deployment_id}-waf"
  description = "ArcGIS Enterprise WAF Rules"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      # Create the "count" block ONLY if waf_mode is "detect"
      dynamic "count" {
        for_each = var.waf_mode == "detect" ? [1] : []
        content {}
      }

      # Create the "none" block ONLY if waf_mode is NOT "detect"
      dynamic "none" {
        for_each = var.waf_mode != "detect" ? [1] : []
        content {}
      }
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"

        # Allow large uploads to pass through WAF by excluding the SizeRestrictions_BODY rule
        rule_action_override {
          action_to_use {
            count {}
          }

          name = "SizeRestrictions_BODY"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      sampled_requests_enabled   = true
      metric_name                = "AWS-AWSManagedRulesCommonRuleSet"
    }
  }

  rule {
    name     = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      # Create the "count" block ONLY if waf_mode is "detect"
      dynamic "count" {
        for_each = var.waf_mode == "detect" ? [1] : []
        content {}
      }

      # Create the "none" block ONLY if waf_mode is NOT "detect"
      dynamic "none" {
        for_each = var.waf_mode != "detect" ? [1] : []
        content {}
      }
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
    }
  }

  rule {
    name     = "AWS-AWSManagedRulesAmazonIpReputationList"
    priority = 3

    override_action {
      # Create the "count" block ONLY if waf_mode is "detect"
      dynamic "count" {
        for_each = var.waf_mode == "detect" ? [1] : []
        content {}
      }

      # Create the "none" block ONLY if waf_mode is NOT "detect"
      dynamic "none" {
        for_each = var.waf_mode != "detect" ? [1] : []
        content {}
      }
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesAmazonIpReputationList"
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesAmazonIpReputationList"
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "arcgis-ingress-waf"
    sampled_requests_enabled   = true
  }
}

resource "aws_wafv2_web_acl_logging_configuration" "waf_logs" {
  log_destination_configs = [aws_cloudwatch_log_group.waf_logs.arn]
  resource_arn            = aws_wafv2_web_acl.arcgis_enterprise.arn
}

resource "aws_wafv2_web_acl_association" "alb_association" {
  resource_arn = aws_lb.alb.arn
  web_acl_arn  = aws_wafv2_web_acl.arcgis_enterprise.arn
}
