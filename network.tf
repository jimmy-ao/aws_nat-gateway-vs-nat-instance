# network.tf

resource "aws_vpc" "main" {
  #checkov:skip=CKV2_AWS_11:No VPC Flow Logs in a lab that lives a few hours; mandatory in production
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name    = "${local.env}-vpc-${local.reg}-nat-showdown"
    Service = "vpc"
    Purpose = "shared"
  }
}

# Adopt the default security group and strip every rule from it: nothing in, nothing out.
resource "aws_default_security_group" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "${local.env}-sg-${local.reg}-default-locked"
    Service = "securityGroup"
    Purpose = "shared"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "${local.env}-igw-${local.reg}-nat-showdown"
    Service = "internetGateway"
    Purpose = "shared"
  }
}

# --- Public subnet: home of the zonal NAT Gateway and the NAT instance ---

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 0) # 10.0.0.0/24
  availability_zone = local.az

  tags = {
    Name    = "${local.env}-subnet-${local.reg}-public"
    Service = "subnet"
    Purpose = "shared"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name    = "${local.env}-rt-${local.reg}-public"
    Service = "routeTable"
    Purpose = "shared"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# --- Private subnet A: egress through the NAT Gateway --------------------

resource "aws_subnet" "private_gw" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 10) # 10.0.10.0/24
  availability_zone = local.az

  tags = {
    Name    = "${local.env}-subnet-${local.reg}-private-zonal-nat-gateway"
    Service = "subnet"
    Purpose = "natGateway"
  }
}

resource "aws_route_table" "private_gw" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name    = "${local.env}-rt-${local.reg}-private-zonal-nat-gateway"
    Service = "routeTable"
    Purpose = "natGateway"
  }
}

resource "aws_route_table_association" "private_gw" {
  subnet_id      = aws_subnet.private_gw.id
  route_table_id = aws_route_table.private_gw.id
}

# --- Private subnet B: egress through the NAT instance -------------------

resource "aws_subnet" "private_inst" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 20) # 10.0.20.0/24
  availability_zone = local.az

  tags = {
    Name    = "${local.env}-subnet-${local.reg}-private-nat-instance"
    Service = "subnet"
    Purpose = "natInstance"
  }
}

resource "aws_route_table" "private_inst" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block           = "0.0.0.0/0"
    network_interface_id = aws_instance.nat.primary_network_interface_id
  }

  tags = {
    Name    = "${local.env}-rt-${local.reg}-private-nat-instance"
    Service = "routeTable"
    Purpose = "natInstance"
  }
}

resource "aws_route_table_association" "private_inst" {
  subnet_id      = aws_subnet.private_inst.id
  route_table_id = aws_route_table.private_inst.id
}
