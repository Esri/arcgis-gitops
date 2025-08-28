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

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  zones = data.aws_availability_zones.available.names
  # Use the first two available zones if the availability zones are not specified.
  availability_zones = length(var.availability_zones) < 2 ? [local.zones[0], local.zones[1]] : var.availability_zones
}

# VPC
resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = var.site_id
  }
}

# Route53 private hosted zone
resource "aws_route53_zone" "private" {
  name = "${var.site_id}.internal"

  vpc {
    vpc_id = aws_vpc.vpc.id
  }
}

# Internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = var.site_id
  }
}

# Elastic Ip address for NAT gateway
resource "aws_eip" "nat" {
  tags = {
    Name = var.site_id
  }
}

# NAT gateway
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_subnets[0].id

  tags = {
    Name = "${var.site_id}/nat"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.igw]
}

# VPC endpoints

resource "aws_security_group" "vpc_endpoints_sg" {
  name        = "${var.site_id}-vpc-endpoints"
  description = "Allow traffic to interface VPC endpoints"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
    # ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${var.site_id}-vpc-endpoints"
  }
}

resource "aws_vpc_endpoint" "gateway" {
  count             = length(var.gateway_vpc_endpoints)
  vpc_id            = aws_vpc.vpc.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.${var.gateway_vpc_endpoints[count.index]}"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.rtb_internal.id]

  tags = {
    Name = "${var.site_id}-${var.gateway_vpc_endpoints[count.index]}"
  }
}

resource "aws_vpc_endpoint" "interface" {
  count             = length(var.interface_vpc_endpoints)
  vpc_id            = aws_vpc.vpc.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.${var.interface_vpc_endpoints[count.index]}"
  vpc_endpoint_type = "Interface"

  subnet_ids = aws_subnet.internal_subnets[*].id

  security_group_ids = [
    aws_security_group.vpc_endpoints_sg.id
  ]

  private_dns_enabled = true

  tags = {
    Name = "${var.site_id}-${var.interface_vpc_endpoints[count.index]}"
  }
}

# Route table for internal subnets
resource "aws_route_table" "rtb_internal" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.site_id}/internal-route-table"
  }
}

# Route table for private subnets
resource "aws_route_table" "rtb_private" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "${var.site_id}/private-route-table"
  }
}

# Route table for public subnets
resource "aws_route_table" "rtb_public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.site_id}/public-route-table"
  }
}

# Internal subnets are routed to VPC endpoints only

resource "aws_subnet" "internal_subnets" {
  count                   = length(local.availability_zones)
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = local.availability_zones[count.index]
  cidr_block              = var.internal_subnets_cidr_blocks[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.site_id}/internal-subnet-${count.index + 1}"
  }
}

# Private subnets

resource "aws_subnet" "private_subnets" {
  count                   = length(local.availability_zones)
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = local.availability_zones[count.index]
  cidr_block              = var.private_subnets_cidr_blocks[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name                              = "${var.site_id}/private-subnet-${count.index + 1}"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# Public subnets

resource "aws_subnet" "public_subnets" {
  count                   = length(local.availability_zones)
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = local.availability_zones[count.index]
  cidr_block              = var.public_subnets_cidr_blocks[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name                     = "${var.site_id}/public-subnet-${count.index + 1}"
    "kubernetes.io/role/elb" = "1"
  }
}

# Subnet to route table associations

resource "aws_route_table_association" "rta_internal_subnets" {
  count          = length(aws_subnet.internal_subnets)
  subnet_id      = aws_subnet.internal_subnets[count.index].id
  route_table_id = aws_route_table.rtb_internal.id
}

resource "aws_route_table_association" "rta_private_subnets" {
  count          = length(aws_subnet.private_subnets)
  subnet_id      = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.rtb_private.id
}

resource "aws_route_table_association" "rta_public_subnets" {
  count          = length(aws_subnet.public_subnets)
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.rtb_public.id
}

