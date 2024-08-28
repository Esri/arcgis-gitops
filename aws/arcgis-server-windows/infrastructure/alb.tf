# Copyright 2024 Esri
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
  vpc_id      = nonsensitive(data.aws_ssm_parameter.vpc_id.value)

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

# Application Load Balancer (ALB)
resource "aws_lb" "alb" {
  name               = var.deployment_id
  internal           = var.internal_load_balancer
  load_balancer_type = "application"
  security_groups    = [aws_security_group.arcgis_alb.id]

  subnets = (var.internal_load_balancer ?
    data.aws_ssm_parameter.private_subnets[*].value :
    data.aws_ssm_parameter.public_subnets[*].value)

  drop_invalid_header_fields = true
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

# Default target group
resource "aws_lb_target_group" "default" {
  name     = "${var.deployment_id}-default"
  port     = 443
  protocol = "HTTPS"
  vpc_id   = nonsensitive(data.aws_ssm_parameter.vpc_id.value)
}

# Create Application Load Balancer target group for HTTPS port 443, attach 
# primary and node instances to it, and add the target group to the load balancer. 
# Configure the target group to forward requests to the HTTP web context.
module "server_https_alb_target" {
  source            = "../../modules/alb_target_group"
  name              = "${var.deployment_id}-443"
  vpc_id            = nonsensitive(data.aws_ssm_parameter.vpc_id.value)
  alb_arn           = aws_lb.alb.arn
  protocol          = "HTTPS"
  alb_port          = 443
  instance_port     = var.instance_https_port
  health_check_path = "/${var.web_context}/rest/info/healthcheck"
  path_patterns     = ["/${var.web_context}", "/${var.web_context}/*"]
  priority          = 100
  target_instances  =  concat([aws_instance.primary.id], [for n in aws_instance.nodes : n.id])
  depends_on = [
    aws_lb_listener.https
  ]
}

# Create Application Load Balancer target group for ArcGIS Server HTTPS port 6443, attach 
# primary and node instances to it, and add the target group to the load balancer. 
# Configure the target group to forward requests to /arcgis HTTP contexts.
module "private_server_https_alb_target" {
  source            = "../../modules/alb_target_group"
  name              = "${var.deployment_id}-6443"
  vpc_id            = nonsensitive(data.aws_ssm_parameter.vpc_id.value)
  alb_arn           = aws_lb.alb.arn
  protocol          = "HTTPS"
  alb_port          = 6443
  instance_port     = 6443
  health_check_path = "/arcgis/rest/info/healthcheck"
  path_patterns     = ["/arcgis", "/arcgis/*"]
  priority          = 100
  target_instances  =  concat([aws_instance.primary.id], [for n in aws_instance.nodes : n.id])
  depends_on = [
    aws_lb_listener.arcgis_server_https
  ]
}


# Create Route 53 record for the Application Load Balancer 
# if the hosted zone ID and domain name are provided.
resource "aws_route53_record" "arcgis_server" {
  count = var.hosted_zone_id != null && var.deployment_fqdn != null ? 1 : 0
  zone_id = var.hosted_zone_id
  name    = "${var.deployment_fqdn}."
  type    = "CNAME"
  ttl     = 300
  records = [aws_lb.alb.dns_name]
}
