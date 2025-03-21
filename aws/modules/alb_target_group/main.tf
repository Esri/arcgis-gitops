/*
 * # Terraform module alb_target_group
 * 
 * The module creates Application Load Balancer target group for specific port and protocol, 
 * attaches specific EC2 instances to it, and adds the target group to the load balancer. 
 * The target group is configured to forward requests for specific path patterns.
 *
 */

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

# Application Load Balancer's target group
resource "aws_lb_target_group" "target_group" {
  name_prefix = var.name
  port        = var.instance_port
  protocol    = var.protocol
  vpc_id      = var.vpc_id
  health_check {
    protocol            = var.protocol
    path                = var.health_check_path
    port                = "traffic-port"
    interval            = 30
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

# Attach EC2 instances to the target group
resource "aws_lb_target_group_attachment" "target_group_attachment" {
  target_group_arn = aws_lb_target_group.target_group.arn
  count            = length(var.target_instances)
  target_id        = var.target_instances[count.index]
  port             = var.instance_port
}

# Retrieve Application Load Balancer's listener attributes
data "aws_lb_listener" "listener" {
  load_balancer_arn = var.alb_arn
  port              = var.alb_port
}

# Forward the specified path patterns from the ALB listener to the target group
resource "aws_lb_listener_rule" "listener_rule" {
  listener_arn = data.aws_lb_listener.listener.arn
  priority     = var.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn
  }

  condition {
    path_pattern {
      values = var.path_patterns
    }
  }
}
