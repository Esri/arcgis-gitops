# Copyright 2025-2026 Esri
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

data "aws_ssm_parameter" "alb_deployment_fqdn" {
  name  = "/arcgis/${var.site_id}/${var.ingress_deployment_id}/deployment-fqdn"
}

data "aws_ssm_parameter" "alb_security_group_id" {
  name  = "/arcgis/${var.site_id}/${var.ingress_deployment_id}/alb/security-group-id"
}

data "aws_ssm_parameter" "alb_arn" {
  name  = "/arcgis/${var.site_id}/${var.ingress_deployment_id}/alb/arn"
}

data "aws_lb" "alb" {
  arn   = data.aws_ssm_parameter.alb_arn.value
}

locals {
  alb_security_group_id = nonsensitive(data.aws_ssm_parameter.alb_security_group_id.value)
  alb_arn               = nonsensitive(data.aws_ssm_parameter.alb_arn.value)
  alb_dns_name          = nonsensitive(data.aws_lb.alb.dns_name)
  deployment_fqdn       = nonsensitive(data.aws_ssm_parameter.alb_deployment_fqdn.value)
}

# Create Application Load Balancer target group for HTTPS port 443, attach 
# primary and node instances to it, and add the target group to the load balancer. 
# Configure the target group to forward requests to the HTTP web context.
module "notebook_server_https_alb_target" {
  source            = "../../modules/alb_target_group"
  name              = substr(var.notebook_server_web_context, 0, 6)
  vpc_id            = module.site_core_info.vpc_id
  alb_arn           = local.alb_arn
  protocol          = "HTTPS"
  alb_port          = 443
  instance_port     = 443
  health_check_path = "/${var.notebook_server_web_context}/rest/info/healthcheck"
  path_patterns     = ["/${var.notebook_server_web_context}", "/${var.notebook_server_web_context}/*"]
  priority          = 120
  target_instances  = concat([aws_instance.primary.id], [for n in aws_instance.nodes : n.id])
}

# Create Application Load Balancer target group for ArcGIS Notebook Server HTTPS port 11443, attach 
# primary and node instances to it, and add the target group to the load balancer. 
# Configure the target group to forward requests to /arcgis HTTP contexts.
module "private_server_https_alb_target" {
  source            = "../../modules/alb_target_group"
  name              = "arcgis"
  vpc_id            = module.site_core_info.vpc_id
  alb_arn           = local.alb_arn
  protocol          = "HTTPS"
  alb_port          = 11443
  instance_port     = 11443
  health_check_path = "/arcgis/rest/info/healthcheck"
  path_patterns     = ["/arcgis", "/arcgis/*"]
  priority          = 120
  target_instances  = concat([aws_instance.primary.id], [for n in aws_instance.nodes : n.id])
}

