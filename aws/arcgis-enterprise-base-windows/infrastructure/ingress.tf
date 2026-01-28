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

data "aws_ssm_parameter" "alb_deployment_fqdn" {
  name  = "/arcgis/${var.site_id}/${var.ingress_deployment_id}/deployment-fqdn"
}

data "aws_ssm_parameter" "alb_arn" {
  name  = "/arcgis/${var.site_id}/${var.ingress_deployment_id}/alb/arn"
}
  
# Create Application Load Balancer target group for HTTPS port 443, attach 
# primary and standby instances to it, and add the target group to the load balancer. 
# Configure the target group to forward requests to /portal and /server HTTP contexts.
module "server_https_alb_target" {
  source            = "../../modules/alb_target_group"
  name              = "server"
  vpc_id            = module.site_core_info.vpc_id
  alb_arn           = nonsensitive(data.aws_ssm_parameter.alb_arn.value)
  protocol          = "HTTPS"
  alb_port          = 443
  instance_port     = 443
  health_check_path = "/${var.server_web_context}/rest/info/healthcheck"
  path_patterns     = ["/${var.server_web_context}", "/${var.server_web_context}/*"]
  priority          = 100
  target_instances  = concat([aws_instance.primary.id], [for n in aws_instance.standby : n.id])
}

# Create Application Load Balancer target group for HTTPS port 443, attach 
# primary and standby instances to it, and add the target group to the load balancer. 
# Configure the target group to forward requests to /portal and /server HTTP contexts.
module "portal_https_alb_target" {
  source            = "../../modules/alb_target_group"
  name              = "portal"
  vpc_id            = module.site_core_info.vpc_id
  alb_arn           = nonsensitive(data.aws_ssm_parameter.alb_arn.value)
  protocol          = "HTTPS"
  alb_port          = 443
  instance_port     = 443
  health_check_path = "/${var.portal_web_context}/portaladmin/healthCheck"
  path_patterns     = ["/${var.portal_web_context}", "/${var.portal_web_context}/*"]
  priority          = 101
  target_instances  = concat([aws_instance.primary.id], [for n in aws_instance.standby : n.id])
}

resource "aws_ssm_parameter" "portal_web_context" {
  name        = "/arcgis/${var.site_id}/${var.deployment_id}/portal-web-context"
  type        = "String"
  value       = var.portal_web_context
  description = "Portal for ArcGIS web context"
}

resource "aws_ssm_parameter" "server_web_context" {
  name        = "/arcgis/${var.site_id}/${var.deployment_id}/server-web-context"
  type        = "String"
  value       = var.server_web_context
  description = "ArcGIS Server web context"
}

resource "aws_ssm_parameter" "deployment_fqdn" {
  name        = "/arcgis/${var.site_id}/${var.deployment_id}/deployment-fqdn"
  type        = "String"
  value       = nonsensitive(data.aws_ssm_parameter.alb_deployment_fqdn.value)
  description = "Fully qualified domain name of the deployment"
}

resource "aws_ssm_parameter" "deployment_url" {
  name        = "/arcgis/${var.site_id}/${var.deployment_id}/deployment-url"
  type        = "String"
  value       = "https://${nonsensitive(data.aws_ssm_parameter.alb_deployment_fqdn.value)}/${var.portal_web_context}"
  description = "Portal for ArcGIS URL of the deployment"
}
