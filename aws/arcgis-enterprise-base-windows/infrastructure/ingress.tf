# Copyright 2024-2025 Esri
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
 
 module "alb" {
  source                 = "../../modules/alb"
  client_cidr_blocks     = var.client_cidr_blocks
  deployment_fqdn        = var.deployment_fqdn
  deployment_id          = var.deployment_id
  http_ports             = [80]
  https_ports            = [443, 6443, 7443, 11443, 13443, 20443, 21443]
  internal_load_balancer = var.internal_load_balancer
  site_id                = var.site_id
  ssl_certificate_arn    = var.ssl_certificate_arn
  ssl_policy             = var.ssl_policy
  subnets = (var.internal_load_balancer ?
             module.site_core_info.private_subnets :
             module.site_core_info.public_subnets)
  vpc_id = module.site_core_info.vpc_id
}

# Create Application Load Balancer target group for HTTPS port 443, attach 
# primary and standby instances to it, and add the target group to the load balancer. 
# Configure the target group to forward requests to /portal and /server HTTP contexts.
module "server_https_alb_target" {
  source            = "../../modules/alb_target_group"
  name              = "server"
  vpc_id            = module.site_core_info.vpc_id
  alb_arn           = module.alb.alb_arn
  protocol          = "HTTPS"
  alb_port          = 443
  instance_port     = 443
  health_check_path = "/${var.server_web_context}/rest/info/healthcheck"
  path_patterns     = ["/${var.server_web_context}", "/${var.server_web_context}/*"]
  priority          = 100
  target_instances  = [aws_instance.primary.id, aws_instance.standby.id]
  depends_on = [
    module.alb
  ]
}

# Create Application Load Balancer target group for HTTPS port 443, attach 
# primary and standby instances to it, and add the target group to the load balancer. 
# Configure the target group to forward requests to /portal and /server HTTP contexts.
module "portal_https_alb_target" {
  source            = "../../modules/alb_target_group"
  name              = "portal"
  vpc_id            = module.site_core_info.vpc_id
  alb_arn           = module.alb.alb_arn
  protocol          = "HTTPS"
  alb_port          = 443
  instance_port     = 443
  health_check_path = "/${var.portal_web_context}/portaladmin/healthCheck"
  path_patterns     = ["/${var.portal_web_context}", "/${var.portal_web_context}/*"]
  priority          = 101
  target_instances  = [aws_instance.primary.id, aws_instance.standby.id]
  depends_on = [
    module.alb
  ]
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

resource "aws_ssm_parameter" "deployment_url" {
  name        = "/arcgis/${var.site_id}/${var.deployment_id}/deployment-url"
  type        = "String"
  value       = "https://${var.deployment_fqdn}/${var.portal_web_context}"
  description = "Portal for ArcGIS URL of the deployment"
}
