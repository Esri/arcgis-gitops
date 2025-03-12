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
 
# EC2 security group for Application Load Balancer
resource "aws_security_group" "arcgis_alb" {
  name        = "${var.deployment_id}-alb"
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
    Name = "${var.deployment_id}-alb"
  }
}

resource "aws_security_group_rule" "allow_http" {
  description       = "Allow client access to HTTP port"
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = var.client_cidr_blocks
  security_group_id = aws_security_group.arcgis_alb.id
}

resource "aws_security_group_rule" "allow_https" {
  description       = "Allow client access to HTTPS port"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.client_cidr_blocks
  security_group_id = aws_security_group.arcgis_alb.id
}

resource "aws_security_group_rule" "allow_arcgis_server_https" {
  description       = "Allow client access to ArcGIS Server HTTPS port"
  type              = "ingress"
  from_port         = 6443
  to_port           = 6443
  protocol          = "tcp"
  cidr_blocks       = var.client_cidr_blocks
  security_group_id = aws_security_group.arcgis_alb.id
}

resource "aws_security_group_rule" "allow_arcgis_portal_https" {
  description       = "Allow client access to Portal for ArcGIS HTTPS port"
  type              = "ingress"
  from_port         = 7443
  to_port           = 7443
  protocol          = "tcp"
  cidr_blocks       = var.client_cidr_blocks
  security_group_id = aws_security_group.arcgis_alb.id
}


# # Allow NAT access on all ports
# resource "aws_security_group_rule" "allow_nat" {
#   description       = "Allow NAT access to all ports"
#   type              = "ingress"
#   from_port         = 0
#   to_port           = 65535
#   protocol          = "tcp"
#   cidr_blocks       = ["${aws_eip.nat.public_ip}/32"]
#   security_group_id = aws_security_group.arcgis_alb.id
# }

# Application Load Balancer (ALB)
resource "aws_lb" "alb" {
  name               = var.deployment_id
  internal           = var.internal_load_balancer
  load_balancer_type = "application"
  security_groups    = [aws_security_group.arcgis_alb.id]

  subnets = (var.internal_load_balancer ?
    module.site_core_info.private_subnets :
    module.site_core_info.public_subnets)

  drop_invalid_header_fields = true

  # access_logs {
  #   bucket  = module.site_core_info.s3_repository
  #   prefix  = "access-logs/${var.deployment_id}"
  #   enabled = true
  # }  
}

# HTTP listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS listener
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = var.ssl_certificate_arn
  ssl_policy        = var.ssl_policy

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.default.arn
  }
}

# ArcGIS Server HTTPS listener
resource "aws_lb_listener" "arcgis_server_https" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "6443"
  protocol          = "HTTPS"
  certificate_arn   = var.ssl_certificate_arn
  ssl_policy        = var.ssl_policy

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.default.arn
  }
}

# Portal for ArcGIS HTTPS listener
resource "aws_lb_listener" "arcgis_portal_https" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "7443"
  protocol          = "HTTPS"
  certificate_arn   = var.ssl_certificate_arn
  ssl_policy        = var.ssl_policy

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.default.arn
  }
}


# Default target group
resource "aws_lb_target_group" "default" {
  name     = "${var.deployment_id}-default"
  port     = 443
  protocol = "HTTPS"
  vpc_id   = module.site_core_info.vpc_id
}

# Create Application Load Balancer target group for HTTP port 80, attach 
# primary and standby instances to it, and add the target group to the load balancer. 
# Configure the target group to forward requests to /server HTTP contexts.
# module "server_http_alb_target" {
#   source            = "../../modules/alb_target_group"
#   name              = "${var.deployment_id}-s-80"
#   vpc_id            = module.site_core_info.vpc_id
#   alb_arn           = aws_lb.alb.arn
#   protocol          = "HTTP"
#   alb_port          = 80
#   instance_port     = 80
#   health_check_path = "/server/rest/info/healthcheck"
#   path_patterns     = ["/server", "/server/*"]
#   priority          = 100
#   target_instances  = [aws_instance.primary.id, aws_instance.standby.id]
#   depends_on = [
#     aws_lb_listener.http
#   ]
# }

# Create Application Load Balancer target group for HTTP port 80, attach 
# primary and standby instances to it, and add the target group to the load balancer. 
# Configure the target group to forward requests to /portal HTTP contexts.
# module "portal_http_alb_target" {
#   source            = "../../modules/alb_target_group"
#   name              = "${var.deployment_id}-p-80"
#   vpc_id            = module.site_core_info.vpc_id
#   alb_arn           = aws_lb.alb.arn
#   protocol          = "HTTP"
#   alb_port          = 80
#   instance_port     = 80
#   health_check_path = "/portal/portaladmin/healthCheck"
#   path_patterns     = ["/portal", "/portal/*"]
#   priority          = 101
#   target_instances  = [aws_instance.primary.id, aws_instance.standby.id]
#   depends_on = [
#     aws_lb_listener.http
#   ]
# }

# Create Application Load Balancer target group for HTTPS port 443, attach 
# primary and standby instances to it, and add the target group to the load balancer. 
# Configure the target group to forward requests to /portal and /server HTTP contexts.
module "server_https_alb_target" {
  source            = "../../modules/alb_target_group"
  name              = "${var.deployment_id}-s-443"
  vpc_id            = module.site_core_info.vpc_id
  alb_arn           = aws_lb.alb.arn
  protocol          = "HTTPS"
  alb_port          = 443
  instance_port     = 443
  health_check_path = "/${var.server_web_context}/rest/info/healthcheck"
  path_patterns     = ["/${var.server_web_context}", "/${var.server_web_context}/*"]
  priority          = 100
  target_instances  = [aws_instance.primary.id, aws_instance.standby.id]
  depends_on = [
    aws_lb_listener.https
  ]
}

# Create Application Load Balancer target group for HTTPS port 443, attach 
# primary and standby instances to it, and add the target group to the load balancer. 
# Configure the target group to forward requests to /portal and /server HTTP contexts.
module "portal_https_alb_target" {
  source            = "../../modules/alb_target_group"
  name              = "${var.deployment_id}-p-443"
  vpc_id            = module.site_core_info.vpc_id
  alb_arn           = aws_lb.alb.arn
  protocol          = "HTTPS"
  alb_port          = 443
  instance_port     = 443
  health_check_path = "/${var.portal_web_context}/portaladmin/healthCheck"
  path_patterns     = ["/${var.portal_web_context}", "/${var.portal_web_context}/*"]
  priority          = 101
  target_instances  = [aws_instance.primary.id, aws_instance.standby.id]
  depends_on = [
    aws_lb_listener.https
  ]
}

# Create Application Load Balancer target group for ArcGIS Server HTTPS port 6443, attach 
# primary and standby instances to it, and add the target group to the load balancer. 
# Configure the target group to forward requests to /arcgis HTTP contexts.
module "private_server_https_alb_target" {
  source            = "../../modules/alb_target_group"
  name              = "${var.deployment_id}-6443"
  vpc_id            = module.site_core_info.vpc_id
  alb_arn           = aws_lb.alb.arn
  protocol          = "HTTPS"
  alb_port          = 6443
  instance_port     = 6443
  health_check_path = "/arcgis/rest/info/healthcheck"
  path_patterns     = ["/arcgis", "/arcgis/*"]
  priority          = 100
  target_instances  = [aws_instance.primary.id, aws_instance.standby.id]
  depends_on = [
    aws_lb_listener.arcgis_server_https
  ]
}

# Create Application Load Balancer target group for Portal for ArcGIS HTTPS port 7443, attach 
# primary and standby instances to it, and add the target group to the load balancer. 
# Configure the target group to forward requests to /arcgis HTTP contexts.
module "private_portal_https_alb_target" {
  source            = "../../modules/alb_target_group"
  name              = "${var.deployment_id}-7443"
  vpc_id            = module.site_core_info.vpc_id
  alb_arn           = aws_lb.alb.arn
  protocol          = "HTTPS"
  alb_port          = 7443
  instance_port     = 7443
  health_check_path = "/arcgis/portaladmin/healthCheck"
  path_patterns     = ["/arcgis", "/arcgis/*"]
  priority          = 100
  target_instances  = [aws_instance.primary.id, aws_instance.standby.id]
  depends_on = [
    aws_lb_listener.arcgis_portal_https
  ]
}

# Create Route 53 record for the Application Load Balancer 
# if the hosted zone ID and domain name are provided.
resource "aws_route53_record" "arcgis_enterprise" {
  count = var.hosted_zone_id != null && var.deployment_fqdn != null ? 1 : 0
  zone_id = var.hosted_zone_id
  name    = "${var.deployment_fqdn}."
  type    = "CNAME"
  ttl     = 300
  records = [aws_lb.alb.dns_name]
}
