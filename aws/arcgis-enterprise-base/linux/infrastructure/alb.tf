data "aws_ssm_parameter" "alb_subnet_1" {
  name = "/arcgis/${var.site_id}/vpc/public-subnet-1"
}

data "aws_ssm_parameter" "alb_subnet_2" {
  name = "/arcgis/${var.site_id}/vpc/public-subnet-2"
}

data "aws_ssm_parameter" "s3_repository" {
  name = "/arcgis/${var.site_id}/s3/repository"
}

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
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.arcgis_alb.id]

  subnets = [
    nonsensitive(data.aws_ssm_parameter.alb_subnet_1.value),
    nonsensitive(data.aws_ssm_parameter.alb_subnet_2.value)
  ]

  drop_invalid_header_fields = true

  # access_logs {
  #   bucket  = nonsensitive(data.aws_ssm_parameter.s3_repository.value)
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
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.ssl_certificate_arn

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
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.ssl_certificate_arn

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
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.ssl_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.default.arn
  }
}


# Default target group
resource "aws_lb_target_group" "default" {
  name     = "alb-default"
  port     = 443
  protocol = "HTTPS"
  vpc_id   = nonsensitive(data.aws_ssm_parameter.vpc_id.value)
}

# Create Application Load Balancer target group for HTTP port 80, attach 
# primary and standby instances to it, and add the target group to the load balancer. 
# Configure the target group to forward requests to /server HTTP contexts.
module "server_http_alb_target" {
  source            = "../../../modules/alb_target_group"
  name              = "server-http"
  vpc_id            = nonsensitive(data.aws_ssm_parameter.vpc_id.value)
  alb_arn           = aws_lb.alb.arn
  protocol          = "HTTP"
  alb_port          = 80
  instance_port     = 80
  health_check_path = "/server/rest/info/healthcheck"
  path_patterns     = ["/server", "/server/*"]
  priority          = 100
  target_instances  = [aws_instance.primary.id, aws_instance.standby.id]
  depends_on = [
    aws_lb_listener.http
  ]
}

# Create Application Load Balancer target group for HTTP port 80, attach 
# primary and standby instances to it, and add the target group to the load balancer. 
# Configure the target group to forward requests to /portal HTTP contexts.
module "portal_http_alb_target" {
  source            = "../../../modules/alb_target_group"
  name              = "portal-http"
  vpc_id            = nonsensitive(data.aws_ssm_parameter.vpc_id.value)
  alb_arn           = aws_lb.alb.arn
  protocol          = "HTTP"
  alb_port          = 80
  instance_port     = 80
  health_check_path = "/portal/portaladmin/healthCheck"
  path_patterns     = ["/portal", "/portal/*"]
  priority          = 101
  target_instances  = [aws_instance.primary.id, aws_instance.standby.id]
  depends_on = [
    aws_lb_listener.http
  ]
}

# Create Application Load Balancer target group for HTTPS port 443, attach 
# primary and standby instances to it, and add the target group to the load balancer. 
# Configure the target group to forward requests to /portal and /server HTTP contexts.
module "server_https_alb_target" {
  source            = "../../../modules/alb_target_group"
  name              = "server-https"
  vpc_id            = nonsensitive(data.aws_ssm_parameter.vpc_id.value)
  alb_arn           = aws_lb.alb.arn
  protocol          = "HTTPS"
  alb_port          = 443
  instance_port     = 443
  health_check_path = "/server/rest/info/healthcheck"
  path_patterns     = ["/server", "/server/*"]
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
  source            = "../../../modules/alb_target_group"
  name              = "portal-https"
  vpc_id            = nonsensitive(data.aws_ssm_parameter.vpc_id.value)
  alb_arn           = aws_lb.alb.arn
  protocol          = "HTTPS"
  alb_port          = 443
  instance_port     = 443
  health_check_path = "/portal/portaladmin/healthCheck"
  path_patterns     = ["/portal", "/portal/*"]
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
  source            = "../../../modules/alb_target_group"
  name              = "arcgis-6443"
  vpc_id            = nonsensitive(data.aws_ssm_parameter.vpc_id.value)
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

# Create Application Load Balancer target group for Portal for ArcGIS HTTPS port 443, attach 
# primary and standby instances to it, and add the target group to the load balancer. 
# Configure the target group to forward requests to /arcgis HTTP contexts.
module "private_portal_https_alb_target" {
  source            = "../../../modules/alb_target_group"
  name              = "arcgis-7443"
  vpc_id            = nonsensitive(data.aws_ssm_parameter.vpc_id.value)
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
