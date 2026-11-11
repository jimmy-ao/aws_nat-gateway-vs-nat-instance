# regional-nat-gateway.tf

resource "aws_nat_gateway" "regional" {
  # Regional mode: one NAT Gateway for the whole VPC, no subnet, no EIP to manage.
  # It expands into every AZ that has network interfaces (automatic mode).
  availability_mode = "regional"
  vpc_id            = aws_vpc.main.id

  tags = {
    Name    = "${local.env}-nat-${local.reg}-regional-nat-gateway"
    Service = "natGateway"
    Purpose = "regionalNatGateway"
  }

  # A Regional NAT Gateway still needs an internet gateway on the VPC.
  depends_on = [aws_internet_gateway.main]
}

# --- Private subnet C: egress through the Regional NAT Gateway ---

resource "aws_subnet" "private_rnat" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 30) # 10.0.30.0/24
  availability_zone = local.az

  tags = {
    Name    = "${local.env}-subnet-${local.reg}-private-regional-nat-gateway"
    Service = "subnet"
    Purpose = "regionalNatGateway"
  }
}

resource "aws_route_table" "private_rnat" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.regional.id
  }

  tags = {
    Name    = "${local.env}-rt-${local.reg}-private-regional-nat-gateway"
    Service = "routeTable"
    Purpose = "regionalNatGateway"
  }
}

resource "aws_route_table_association" "private_rnat" {
  subnet_id      = aws_subnet.private_rnat.id
  route_table_id = aws_route_table.private_rnat.id
}
