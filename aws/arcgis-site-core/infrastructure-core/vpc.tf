data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  availability_zones = length(var.availability_zones) < 2 ? data.aws_availability_zones.available.names : var.availability_zones
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
  name = var.hosted_zone_name

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
  subnet_id     = aws_subnet.public_subnet_1.id

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
  description = "Allow traffic to the VPC endpoints"
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

resource "aws_vpc_endpoint" "s3" {
  count = var.isolated_subnets ? 1 : 0
  vpc_id            = aws_vpc.vpc.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.rtb_isolated[0].id]

  tags = {
    Name = "${var.site_id}-s3"
  }
}

resource "aws_vpc_endpoint" "dynamodb" {
  count = var.isolated_subnets ? 1 : 0
  vpc_id            = aws_vpc.vpc.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.rtb_isolated[0].id]

  tags = {
    Name = "${var.site_id}-dynamodb"
  }
}

resource "aws_vpc_endpoint" "ssm" {
  count = var.isolated_subnets ? 1 : 0
  vpc_id            = aws_vpc.vpc.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.ssm"
  vpc_endpoint_type = "Interface"

  subnet_ids = [
    aws_subnet.isolated_subnet_1[0].id,
    aws_subnet.isolated_subnet_2[0].id
  ]

  security_group_ids = [
    aws_security_group.vpc_endpoints_sg.id
  ]

  private_dns_enabled = true

  tags = {
    Name = "${var.site_id}-ssm"
  }
}

resource "aws_vpc_endpoint" "ec2messages" {
  count = var.isolated_subnets ? 1 : 0
  vpc_id            = aws_vpc.vpc.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.ec2messages"
  vpc_endpoint_type = "Interface"

  subnet_ids = [
    aws_subnet.isolated_subnet_1[0].id,
    aws_subnet.isolated_subnet_2[0].id
  ]

  security_group_ids = [
    aws_security_group.vpc_endpoints_sg.id
  ]

  private_dns_enabled = true

  tags = {
    Name = "${var.site_id}-ec2messages"
  }
}

resource "aws_vpc_endpoint" "ssmmessages" {
  count = var.isolated_subnets ? 1 : 0
  vpc_id            = aws_vpc.vpc.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.ssmmessages"
  vpc_endpoint_type = "Interface"

  subnet_ids = [
    aws_subnet.isolated_subnet_1[0].id,
    aws_subnet.isolated_subnet_2[0].id
  ]

  security_group_ids = [
    aws_security_group.vpc_endpoints_sg.id
  ]

  private_dns_enabled = true

  tags = {
    Name = "${var.site_id}-ssmmessages"
  }
}

resource "aws_vpc_endpoint" "monitoring" {
  count = var.isolated_subnets ? 1 : 0
  vpc_id            = aws_vpc.vpc.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.monitoring"
  vpc_endpoint_type = "Interface"

  subnet_ids = [
    aws_subnet.isolated_subnet_1[0].id,
    aws_subnet.isolated_subnet_2[0].id
  ]

  security_group_ids = [
    aws_security_group.vpc_endpoints_sg.id
  ]

  private_dns_enabled = true

  tags = {
    Name = "${var.site_id}-monitoring"
  }
}

resource "aws_vpc_endpoint" "logs" {
  count = var.isolated_subnets ? 1 : 0
  vpc_id            = aws_vpc.vpc.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.logs"
  vpc_endpoint_type = "Interface"

  subnet_ids = [
    aws_subnet.isolated_subnet_1[0].id,
    aws_subnet.isolated_subnet_2[0].id
  ]

  security_group_ids = [
    aws_security_group.vpc_endpoints_sg.id
  ]

  private_dns_enabled = true

  tags = {
    Name = "${var.site_id}-logs"
  }
}

# Route table for isolated subnets
resource "aws_route_table" "rtb_isolated" {
  count = var.isolated_subnets ? 1 : 0
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.site_id}/isolated-route-table"
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

# Isolated subnets are routed to VPC endpoints only

resource "aws_subnet" "isolated_subnet_1" {
  count = var.isolated_subnets ? 1 : 0
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = local.availability_zones[0]
  cidr_block              = var.isolated_subnet1_cidr_block
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.site_id}/isolated-subnet-1"
  }
}

resource "aws_subnet" "isolated_subnet_2" {
  count = var.isolated_subnets ? 1 : 0
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = local.availability_zones[1]
  cidr_block              = var.isolated_subnet2_cidr_block
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.site_id}/isolated-subnet-2"
  }
}

# Private subnets

resource "aws_subnet" "private_subnet_1" {
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = local.availability_zones[0]
  cidr_block              = var.private_subnet1_cidr_block
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.site_id}/private-subnet-1"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = local.availability_zones[1]
  cidr_block              = var.private_subnet2_cidr_block
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.site_id}/private-subnet-2"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# Public subnets

resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = local.availability_zones[0]
  cidr_block              = var.public_subnet1_cidr_block
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.site_id}/public-subnet-1"
    "kubernetes.io/role/elb" = "1"    
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = local.availability_zones[1]
  cidr_block              = var.public_subnet2_cidr_block
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.site_id}/public-subnet-2"
    "kubernetes.io/role/elb" = "1"
  }
}

# Subnet to route table associations

resource "aws_route_table_association" "rta_isolated_subnet_1" {
  count = var.isolated_subnets ? 1 : 0  
  subnet_id      = aws_subnet.isolated_subnet_1[0].id
  route_table_id = aws_route_table.rtb_isolated[0].id
}

resource "aws_route_table_association" "rta_isolated_subnet_2" {
  count = var.isolated_subnets ? 1 : 0
  subnet_id      = aws_subnet.isolated_subnet_2[0].id
  route_table_id = aws_route_table.rtb_isolated[0].id
}

resource "aws_route_table_association" "rta_private_subnet_1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.rtb_private.id
}

resource "aws_route_table_association" "rta_private_subnet_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.rtb_private.id
}

resource "aws_route_table_association" "rta_public_subnet_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.rtb_public.id
}

resource "aws_route_table_association" "rta_public_subnet_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.rtb_public.id
}

