# nat-instance.tf

### data 

data "aws_ssm_parameter" "al2023_arm64" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

### resources

resource "aws_security_group" "nat_instance" {
  #checkov:skip=CKV_AWS_382:A NAT forwards to any destination, that is the job description
  name        = "${local.env}-sg-${local.reg}-nat-instance"
  description = "Accept traffic from the private subnet, send it anywhere"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Everything from the subnet routed through this instance"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_subnet.private_inst.cidr_block]
  }

  egress {
    description = "NAT: forward to any destination on the internet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${local.env}-sg-${local.reg}-nat-instance"
    Service = "securityGroup"
    Purpose = "natInstance"
  }
}

resource "aws_instance" "nat" {
  #checkov:skip=CKV_AWS_126:Detailed monitoring is not worth paying for in a lab that lives a few hours
  ami                    = data.aws_ssm_parameter.al2023_arm64.value
  instance_type          = "t4g.nano"
  ebs_optimized          = true
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.nat_instance.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm.name

  # The single most important line in this file. See "Gotchas".
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
    sysctl --system

    # 2. Masquerade private subnet B traffic leaving the primary interface (ens5 on AL2023, not eth0)
    dnf install -y iptables-services
    IFACE=$(ip -o -4 route show to default | awk '{print $5}')
    iptables -t nat -A POSTROUTING -o "$IFACE" -s ${aws_subnet.private_inst.cidr_block} -j MASQUERADE

    # 3. Persist ONLY our rules, then start the service (order matters, see "Gotchas")
    iptables-save > /etc/sysconfig/iptables
    systemctl enable --now iptables
  EOF

  tags = {
    Name    = "${local.env}-ec2-${local.reg}-nat-instance"
    Service = "ec2Instance"
    Purpose = "natInstance"
  }
}

resource "aws_eip" "nat_instance" {
  domain   = "vpc"
  instance = aws_instance.nat.id

  tags = {
    Name    = "${local.env}-eip-${local.reg}-nat-instance"
    Service = "elasticIP"
    Purpose = "natInstance"
  }

  depends_on = [aws_internet_gateway.main]
}
