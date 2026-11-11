# zone-nat-gateway.tf

resource "aws_eip" "nat_gateway" {
  domain = "vpc"

  tags = {
    Name    = "${local.env}-eip-${local.reg}-zonal-nat-gateway"
    Service = "elasticIP"
    Purpose = "natGateway"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat_gateway.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name    = "${local.env}-nat-${local.reg}-zonal-nat-gateway"
    Service = "natGateway"
    Purpose = "natGateway"
  }

  depends_on = [aws_internet_gateway.main]
}
