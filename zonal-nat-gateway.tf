# zonal-nat-gateway.tf

### nat gateway

resource "aws_eip" "zonal_nat_gateway" {
  domain = "vpc"

  tags = {
    Name    = "${local.env}-eip-${local.reg}-znat"
    Service = "elasticIP"
    Purpose = "zonalNatGateway"
  }
}

resource "aws_nat_gateway" "zonal" {
  allocation_id = aws_eip.zonal_nat_gateway.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name    = "${local.env}-ngtw-${local.az_naming}-zonal"
    Service = "natGateway"
    Purpose = "zonalNatGateway"
  }

  depends_on = [aws_internet_gateway.main]
}

# private subnet a • egress through the nat gateway

resource "aws_subnet" "private_znat" {
  vpc_id = aws_vpc.main.id

  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 10)
  availability_zone = local.az

  tags = {
    Name    = "${local.env}-sb-${local.az_naming}-private-znat"
    Service = "subnet"
    Purpose = "zonalNatGateway"
  }
}

resource "aws_route_table" "private_znat" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.zonal.id
  }

  tags = {
    Name    = "${local.env}-rt-${local.az_naming}-private-znat"
    Service = "routeTable"
    Purpose = "zonalNatGateway"
  }
}

resource "aws_route_table_association" "private_znat" {
  subnet_id      = aws_subnet.private_znat.id
  route_table_id = aws_route_table.private_znat.id
}
