/*
 * # Terraform module ingress
 * 
 * The module creates and configures an Application Load Balancer for ArcGIS Enterprise site.
 *
 * ![Site ingress](ingress.png "Site ingress architecture")
 *
 * It sets up a security group, HTTP and HTTPS listeners, and a default target group for the load balancer.
 * HTTP port 80 is redirected to HTTPS port 443. 
 *
 * The load balancer can be either internal or internet-facing. 
 * Internet-facing load balancer is configured to use two of the public VPC subnets, 
 * while internal load balancer uses the private subnets.
 *
 * The module creates a Web Application Firewall (WAF) Web ACL and associates it with the Application Load Balancer.
 * The Web ACL is configured with a set of managed rules to protect the load balancer from common web exploits.
 * The WAF mode can be set either to "detect" (default) or "protect". 
 * In "detect" mode, the WAF only counts and logs the requests that match the rules,
 * while in "protect" mode, the WAF blocks the requests.
 *
 * If a Route 53 hosted zone ID is provided, an alias record is created in the hosted zone
 * that points the deployment's FQDN to the load balancer's DNS name. The DNS name is also stored in 
 * "/arcgis/${var.site_id}/${var.deployment_id}/alb/dns-name" SSM parameter.
 * 
 * The module also creates a private Route 53 hosted zone for the deployment FQDN and an alias record 
 * in the hosted zone for the load balancer DNS name.
 * This makes the deployment FQDN always addressable from the VPC subnets. 
 *
 * The deployment's Monitoring Subsystem consists of:
 *
 * * A CloudWatch alarm that monitors the target groups and posts to the SNS topic if the number of unhealthy instances. 
 *   in the target groups is nonzero. 
 * * A CloudWatch log group for AWS WAF logs.
 * * A CloudWatch dashboard that displays the CloudWatch alerts, metrics, and logs of the deployment.
 *
 * ## Requirements
 * 
 * On the machine where Terraform is executed:
 * 
 * * Python 3.8 or later with [AWS SDK for Python (Boto3)](https://aws.amazon.com/sdk-for-python/) package must be installed.
 * * AWS credentials must be configured.
 *
 * Before applying the module, an SSL certificate for the base ArcGIS Enterprise deployment FQDN 
 * must be imported into or issued by AWS Certificate Manager service in the AWS account. The certificate's
 * ARN specified by "ssl_certificate_arn" input variable will be used to configure HTTPS listeners of the load balancer.
 *
 * After applying the module, the deployment FQDN also must be pointed to the DNS name of the Application Load Balancer
 * exported by "alb_dns_name" output value of the module.
 *
 * ## SSM Parameters
 *
 * The module reads the following SSM parameters: 
 *
 * | SSM parameter name | Description |
 * |--------------------|-------------|
 * | /arcgis/${var.site_id}/iam/instance-profile-name | IAM instance profile name |
 * | /arcgis/${var.site_id}/s3/backup | S3 bucket used by deployments to store backup data |
 * | /arcgis/${var.site_id}/s3/logs | S3 bucket used by deployments to store logs |
 * | /arcgis/${var.site_id}/s3/repository | S3 bucket of private repository |
 * | /arcgis/${var.site_id}/s3/region | S3 bucket region |
 * | /arcgis/${var.site_id}/sns-topics/site-alarms | Site alarms SNS topic ARN |
 * | /arcgis/${var.site_id}/vpc/hosted-zone-id | VPC hosted zone ID |
 * | /arcgis/${var.site_id}/vpc/id | VPC ID |
 * | /arcgis/${var.site_id}/vpc/subnets | IDs of VPC subnets |
 *
 * The module writes the following SSM parameters:
 *
 * | SSM parameter name | Description |
 * |--------------------|-------------|
 * | /arcgis/${var.site_id}/${var.deployment_id}/alb/arn | ARN of the application load balancer |
 * | /arcgis/${var.site_id}/${var.deployment_id}/alb/dns-name | DNS name of the application load balancer |
 * | /arcgis/${var.site_id}/${var.deployment_id}/alb/security-group-id | Security group ID of the application load balancer |
 * | /arcgis/${var.site_id}/${var.deployment_id}/deployment-fqdn | Fully qualified domain name of the site ingress |
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

terraform {
  backend "s3" {
    key = "arcgis/aws/enterprise-ingress/ingress.tfstate"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.10"
    }
  }

  required_version = ">= 1.10.0"
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ArcGISAutomation   = "arcgis-gitops"
      ArcGISSiteId       = var.site_id
      ArcGISDeploymentId = var.deployment_id
    }
  }
}

data "aws_region" "current" {}

module "site_core_info" {
  source  = "../../modules/site_core_info"
  site_id = var.site_id
}

# EC2 security group for Application Load Balancer
resource "aws_security_group" "arcgis_alb" {
  name        = "${var.site_id}-${var.deployment_id}-alb"
  description = "Allow inbound traffic to load balancer ports"
  vpc_id      = module.site_core_info.vpc_id

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${var.site_id}-${var.deployment_id}-alb"
  }
}

resource "aws_security_group_rule" "allow_http" {
  count             = length(var.http_ports)
  description       = "Allow client access to port ${var.http_ports[count.index]}"
  type              = "ingress"
  from_port         = var.http_ports[count.index]
  to_port           = var.http_ports[count.index]
  protocol          = "tcp"
  cidr_blocks       = var.client_cidr_blocks
  security_group_id = aws_security_group.arcgis_alb.id
}

resource "aws_security_group_rule" "allow_https" {
  count             = length(var.https_ports)
  description       = "Allow client access to port ${var.https_ports[count.index]}"
  type              = "ingress"
  from_port         = var.https_ports[count.index]
  to_port           = var.https_ports[count.index]
  protocol          = "tcp"
  cidr_blocks       = var.client_cidr_blocks
  security_group_id = aws_security_group.arcgis_alb.id
}

# Application Load Balancer (ALB)
resource "aws_lb" "alb" {
  name               = "${var.site_id}-${var.deployment_id}"
  internal           = var.internal_load_balancer
  load_balancer_type = "application"
  security_groups    = [aws_security_group.arcgis_alb.id]

  subnets = (var.internal_load_balancer ?
    module.site_core_info.private_subnets :
  module.site_core_info.public_subnets)

  drop_invalid_header_fields = true

  access_logs {
    bucket  = module.site_core_info.s3_logs
    enabled = var.enable_access_log
  }
}

# Default target group
resource "aws_lb_target_group" "default" {
  port     = 443
  protocol = "HTTPS"
  vpc_id   = module.site_core_info.vpc_id
}

# Redirect HTTP listeners to corresponding HTTPS listeners
resource "aws_lb_listener" "http" {
  count             = length(var.http_ports)
  load_balancer_arn = aws_lb.alb.arn
  port              = var.http_ports[count.index]
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = var.https_ports[count.index]
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS listeners
resource "aws_lb_listener" "https" {
  count             = length(var.https_ports)
  load_balancer_arn = aws_lb.alb.arn
  port              = var.https_ports[count.index]
  protocol          = "HTTPS"
  certificate_arn   = var.ssl_certificate_arn
  ssl_policy        = var.ssl_policy

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.default.arn
  }
}

resource "aws_ssm_parameter" "alb_security_group_id" {
  name        = "/arcgis/${var.site_id}/${var.deployment_id}/alb/security-group-id"
  type        = "String"
  value       = aws_security_group.arcgis_alb.id
  description = "Security group Id of the deployment's ALB"
}

resource "aws_ssm_parameter" "alb_arn" {
  name        = "/arcgis/${var.site_id}/${var.deployment_id}/alb/arn"
  type        = "String"
  value       = aws_lb.alb.arn
  description = "ARN of the deployment's ALB"
}

resource "aws_ssm_parameter" "alb_dns_name" {
  name        = "/arcgis/${var.site_id}/${var.deployment_id}/alb/dns-name"
  type        = "String"
  value       = aws_lb.alb.dns_name
  description = "DNS name of the deployment's ALB"
}

resource "aws_ssm_parameter" "deployment_fqdn" {
  name        = "/arcgis/${var.site_id}/${var.deployment_id}/deployment-fqdn"
  type        = "String"
  value       = var.deployment_fqdn
  description = "Fully qualified domain name of the deployment"
}

# Route53 private hosted zone for the deployment FQDN

resource "aws_route53_zone" "deployment_fqdn" {
  name = var.deployment_fqdn

  vpc {
    vpc_id = module.site_core_info.vpc_id
  }
}

# Create Route 53 record for the Application Load Balancer 
resource "aws_route53_record" "deployment_fqdn" {
  zone_id = aws_route53_zone.deployment_fqdn.zone_id
  name    = "" # Apex domain name
  type    = "A"
  alias {
    name                   = aws_lb.alb.dns_name
    zone_id                = aws_lb.alb.zone_id
    evaluate_target_health = false
  }
}

# Create Route 53 record in the provided public hosted zone for the Application Load Balancer
resource "aws_route53_record" "arcgis_enterprise" {
  count   = var.hosted_zone_id != null ? 1 : 0
  zone_id = var.hosted_zone_id
  name    = "${var.deployment_fqdn}."
  type    = "A"
  alias {
    name                   = aws_lb.alb.dns_name
    zone_id                = aws_lb.alb.zone_id
    evaluate_target_health = false
  }
}
