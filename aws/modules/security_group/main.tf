/*
 * # Terraform module security_group
 * 
 * Terraform module creates and configures EC2 security group for deployment.
 * 
 * The module configures the following ingress rules:
 *
 * - Allows the security group access to itself on all TCP ports,
 * - Allows access from Application Load Balancer's security group specified by alb_security_group_id variable to TCP ports specified by alb_ports variable,
 * 
 * The module allows egress for all ports on all IP addresses. 
 */

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

resource "aws_security_group" "security_group" {
  name        = var.name
  description = "Allow traffic to the deployment EC2 instances"
  vpc_id      = var.vpc_id

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = var.name
  }
}

resource "aws_security_group_rule" "allow_self" {
  description       = "Allow the security group access to itself on all TCP ports"
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  self              = true
  security_group_id = aws_security_group.security_group.id
}

# Grant the security group access to ALB security group

# resource "aws_security_group_rule" "allow_alb_callback" {
#   description       = "Allow the security group access to ALB on all TCP ports"
#   type              = "ingress"
#   from_port         = 0
#   to_port           = 65535
#   protocol          = "tcp"
#   source_security_group_id = aws_security_group.security_group.id
#   security_group_id = var.alb_security_group_id
# }

resource "aws_security_group_rule" "allow_alb" {
  count = length(var.alb_ports)
  description       = "Allow access from ALB to TCP port ${var.alb_ports[count.index]}"
  type              = "ingress"
  from_port         = var.alb_ports[count.index]
  to_port           = var.alb_ports[count.index]
  protocol          = "tcp"
  source_security_group_id = var.alb_security_group_id
  security_group_id = aws_security_group.security_group.id
}
