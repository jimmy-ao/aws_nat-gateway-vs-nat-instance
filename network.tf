# network.tf

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name    = "${local.env}-vpc-${local.reg}-nat-showdown"
    Service = "vpc"
    Purpose = "natShowdown"
  }
}

resource "aws_default_security_group" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "${local.env}-sg-${local.reg}-default-locked"
    Service = "securityGroup"
    Purpose = "natShowdown"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "${local.env}-igw-${local.reg}-nat-showdown"
    Service = "internetGateway"
    Purpose = "natShowdown"
  }
}

# public subnet • home of the zonal nat gateway and the nat instance

resource "aws_subnet" "public" {
  vpc_id = aws_vpc.main.id

  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 0)
  availability_zone = local.az

  tags = {
    Name    = "${local.env}-sb-${local.reg}-public"
    Service = "subnet"
    Purpose = "natShowdown"
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
    Purpose = "natShowdown"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
