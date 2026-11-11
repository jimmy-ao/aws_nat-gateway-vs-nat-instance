# test-instances.tf

resource "aws_iam_role" "ssm" {
  name = "${local.env}-role-glb-ssm-lab-instances"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name    = "${local.env}-role-glb-ssm-lab-instances"
    Service = "iamRole"
    Purpose = "natShowdown"
  }
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm" {
  name = "${local.env}-profile-glb-ssm-lab-instances"
  role = aws_iam_role.ssm.name

  tags = {
    Name    = "${local.env}-profile-glb-ssm-lab-instances"
    Service = "iamInstanceProfile"
    Purpose = "natShowdown"
  }
}

resource "aws_security_group" "test" {
  name        = "${local.env}-sg-${local.reg}-test-instances"
  description = "HTTPS out only, nothing in"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "HTTPS only: SSM, dnf and the egress check"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${local.env}-sg-${local.reg}-test-instances"
    Service = "securityGroup"
    Purpose = "natShowdown"
  }
}

locals {
  test_subnets = {
    via-zonal-nat-gateway = { subnet_id = aws_subnet.private_znat.id, purpose = "zonalNatGateway" }
    via-nat-instance      = { subnet_id = aws_subnet.private_inat.id, purpose = "natInstance" }
    via-regional-nat      = { subnet_id = aws_subnet.private_rnat.id, purpose = "regionalNatGateway" }
  }
}

resource "aws_instance" "test" {
  for_each = local.test_subnets

  ami                    = data.aws_ssm_parameter.al2023_arm64.value
  instance_type          = "t4g.nano"
  ebs_optimized          = true
  subnet_id              = each.value.subnet_id
  vpc_security_group_ids = [aws_security_group.test.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm.name

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    encrypted = true
  }

  tags = {
    Name    = "${local.env}-ec2-${local.reg}-test-${each.key}"
    Service = "ec2Instance"
    Purpose = each.value.purpose
  }

  depends_on = [
    aws_route_table_association.private_znat,
    aws_route_table_association.private_inat,
    aws_route_table_association.private_rnat,
    aws_eip.nat_instance,
  ]
}
