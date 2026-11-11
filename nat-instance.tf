# nat-instance.tf

data "aws_ssm_parameter" "al2023_arm64" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

resource "aws_eip" "nat_instance" {
  domain   = "vpc"
  instance = aws_instance.nat_instance.id

  tags = {
    Name    = "${local.env}-eip-${local.reg}-inat-${local.az_naming}"
    Service = "elasticIP"
    Purpose = "natInstance"
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_security_group" "nat_instance" {
  #checkov:skip=CKV_AWS_382:A NAT forwards to any destination, that is the job description
  vpc_id = aws_vpc.main.id

  name        = "${local.env}-sg-${local.reg}-inat"
  description = "Accept traffic from the private subnet, send it anywhere"

  ingress {
    description = "Everything from the subnet routed through this instance"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_subnet.private_inat.cidr_block]
  }

  egress {
    description = "NAT: forward to any destination on the internet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${local.env}-sg-${local.reg}-inat"
    Service = "securityGroup"
    Purpose = "natInstance"
  }
}

resource "aws_instance" "nat_instance" {
  #checkov:skip=CKV_AWS_126:Detailed monitoring is not worth paying for in a lab that lives a few hours
  ami                    = data.aws_ssm_parameter.al2023_arm64.value
  instance_type          = "t4g.nano"
  ebs_optimized          = true
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.nat_instance.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm.name

  # The single most important line in this file.
  source_dest_check = false

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    encrypted = true
  }

  user_data_replace_on_change = true
  user_data                   = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    # 1. Let the kernel forward packets between interfaces
    echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/90-nat.conf
    sysctl -p /etc/sysctl.d/90-nat.conf

    # 2. AL2023 ships without iptables. The instance boots before its Elastic IP is attached,
    #    so the internet may not be there yet: retry for 5 minutes instead of dying on the first try
    n=0
    until dnf install -y iptables-services; do
      n=$((n + 1))
      [ "$n" -lt 30 ] || exit 1
      sleep 10
    done

    # 3. Masquerade private subnet B traffic leaving the primary interface (ens5 on AL2023, not eth0)
    IFACE=$(ip -o -4 route show to default | awk '{print $5}')
    iptables -t nat -A POSTROUTING -o "$IFACE" -s ${aws_subnet.private_inat.cidr_block} -j MASQUERADE

    # 4. Persist ONLY our rules, then start the service (order matters, see "Gotchas")
    iptables-save > /etc/sysconfig/iptables
    systemctl enable --now iptables
  EOF

  tags = {
    Name    = "${local.env}-ec2-${local.az_naming}-inat"
    Service = "ec2Instance"
    Purpose = "natInstance"
  }
}

# private subnet b • egress through the nat instance

resource "aws_subnet" "private_inat" {
  vpc_id = aws_vpc.main.id

  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 20)
  availability_zone = local.az

  tags = {
    Name    = "${local.env}-sb-${local.az_naming}-private-inat"
    Service = "subnet"
    Purpose = "natInstance"
  }
}

resource "aws_route_table" "private_inat" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block           = "0.0.0.0/0"
    network_interface_id = aws_instance.nat_instance.primary_network_interface_id
  }

  tags = {
    Name    = "${local.env}-rt-${local.az_naming}-private-inat"
    Service = "routeTable"
    Purpose = "natInstance"
  }
}

resource "aws_route_table_association" "private_inat" {
  subnet_id      = aws_subnet.private_inat.id
  route_table_id = aws_route_table.private_inat.id
}
