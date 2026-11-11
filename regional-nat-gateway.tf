# regional-nat-gateway.tf

resource "aws_nat_gateway" "regional" {
  vpc_id = aws_vpc.main.id

  availability_mode = "regional"

  tags = {
    Name    = "${local.env}-ngtw-${local.reg}-regional"
    Service = "natGateway"
    Purpose = "regionalNatGateway"
  }

  depends_on = [aws_internet_gateway.main]
}

### private subnet c • egress through the regional nat gateway

resource "aws_subnet" "private_rnat" {
  vpc_id = aws_vpc.main.id

  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 30)
  availability_zone = local.az

  tags = {
    Name    = "${local.env}-sb-${local.az_naming}-private-rnat"
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
    Name    = "${local.env}-rt-${local.az_naming}-private-rnat"
    Service = "routeTable"
    Purpose = "regionalNatGateway"
  }
}

resource "aws_route_table_association" "private_rnat" {
  subnet_id      = aws_subnet.private_rnat.id
  route_table_id = aws_route_table.private_rnat.id
}
