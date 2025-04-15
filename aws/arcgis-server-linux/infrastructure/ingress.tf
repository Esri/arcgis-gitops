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

# If alb_deployment_id is not null, then the ALB from that deployment is used.
# In this case, the ALB security group ID and ARN are retrieved from SSM parameters.
# Otherwise, the ALB is being created in the same stack and the

data "aws_ssm_parameter" "alb_security_group_id" {
  count = var.alb_deployment_id == null ? 0 : 1
  name  = "/arcgis/${var.site_id}/${var.alb_deployment_id}/alb/security-group-id"
}

data "aws_ssm_parameter" "alb_arn" {
  count = var.alb_deployment_id == null ? 0 : 1
  name  = "/arcgis/${var.site_id}/${var.alb_deployment_id}/alb/arn"
}

data "aws_lb" "alb" {
  count = var.alb_deployment_id == null ? 0 : 1
  arn   = data.aws_ssm_parameter.alb_arn[0].value
}

locals {
  alb_security_group_id = var.alb_deployment_id == null ? module.alb[0].security_group_id : data.aws_ssm_parameter.alb_security_group_id[0].value
  alb_arn               = var.alb_deployment_id == null ? module.alb[0].alb_arn : data.aws_ssm_parameter.alb_arn[0].value
  alb_dns_name          = var.alb_deployment_id == null ? module.alb[0].alb_dns_name : data.aws_lb.alb[0].dns_name
}

module "alb" {
  count                  = var.alb_deployment_id == null ? 1 : 0
  source                 = "../../modules/alb"
  client_cidr_blocks     = var.client_cidr_blocks
  deployment_fqdn        = var.deployment_fqdn
  deployment_id          = var.deployment_id
  http_ports             = [80, 6080]
  https_ports            = [443, 6443]
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
# primary and node instances to it, and add the target group to the load balancer. 
# Configure the target group to forward requests to the HTTP web context.
module "server_https_alb_target" {
  source            = "../../modules/alb_target_group"
  name              = substr(var.server_web_context, 0, 6)
  vpc_id            = module.site_core_info.vpc_id
  alb_arn           = local.alb_arn
  protocol          = "HTTPS"
  alb_port          = 443
  instance_port     = var.use_webadaptor ? 443 : 6443
  health_check_path = "/${var.server_web_context}/rest/info/healthcheck"
  path_patterns     = ["/${var.server_web_context}", "/${var.server_web_context}/*"]
  priority          = 110
  target_instances  = concat([aws_instance.primary.id], [for n in aws_instance.nodes : n.id])
  depends_on = [
    module.alb
  ]
}

# Create Application Load Balancer target group for ArcGIS Server HTTPS port 6443, attach 
# primary and node instances to it, and add the target group to the load balancer. 
# Configure the target group to forward requests to /arcgis HTTP contexts.
# This target group is only created if the deployment is not using an existing ALB, because
# only one target group can use port 6443 and with "arcgis" web context.
module "private_server_https_alb_target" {
  count             = var.alb_deployment_id == null ? 1 : 0
  source            = "../../modules/alb_target_group"
  name              = "arcgis"
  vpc_id            = module.site_core_info.vpc_id
  alb_arn           = local.alb_arn
  protocol          = "HTTPS"
  alb_port          = 6443
  instance_port     = 6443
  health_check_path = "/arcgis/rest/info/healthcheck"
  path_patterns     = ["/arcgis", "/arcgis/*"]
  priority          = 110
  target_instances  = concat([aws_instance.primary.id], [for n in aws_instance.nodes : n.id])
  depends_on = [
    module.alb
  ]
}
