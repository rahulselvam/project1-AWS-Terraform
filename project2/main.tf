# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

provider "aws" {
  region = "eu-central-1"

  default_tags {
    tags = {
      hashicorp-learn = "aws-asg"
    }
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.0.1"

  name = "main-vpc"
  cidr = "10.0.0.0/16"

  azs                  = data.aws_availability_zones.available.names
  public_subnets       = ["10.0.2.0/24", "10.0.4.0/24", "10.0.6.0/24"]
  private_subnets      = ["10.0.1.0/24", "10.0.3.0/24", "10.0.5.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_vpn_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"] # Or your AWS account ID
  filter {
    name   = "name"
    values = ["al2023-ami-2023.8.20250721.2-kernel-6.1-x86_64"] # Filter for Amazon Linux 2 AMIs
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name = "root-device-type"
    values = ["ebs"]
  }
}

resource "aws_launch_template" "project2" {
  name_prefix     = "project2-aws-asg-"
  image_id        = data.aws_ami.amazon_linux.id
  instance_type   = "t2.micro"
  # network_interfaces {
  #   associate_public_ip_address = true
  #   security_groups = [aws_security_group.project2_instance.id]
  # }
  user_data       = filebase64("${path.module}/user-data.sh")
  vpc_security_group_ids = [aws_security_group.project2_instance.id]
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "project2" {
  name                 = "project2"
  min_size             = 1
  max_size             = 3
  desired_capacity     = 1
  launch_template {
    id      = aws_launch_template.project2.id
    version = "$Latest"
  }
  vpc_zone_identifier  = module.vpc.private_subnets
  #vpc_zone_identifier  = module.vpc.public_subnets

  health_check_type    = "ELB"

  tag {
    key                 = "Name"
    value               = "project2"
    propagate_at_launch = true
  }
}

resource "aws_lb" "project2" {
  name               = "project2-asg-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.project2_lb.id]
  subnets =          module.vpc.public_subnets
}

resource "aws_lb_listener" "project2" {
  load_balancer_arn = aws_lb.project2.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.project2.arn
  }
}

resource "aws_lb_target_group" "project2" {
  name     = "asg-project2"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
}


resource "aws_autoscaling_attachment" "project2" {
  autoscaling_group_name = aws_autoscaling_group.project2.id
  lb_target_group_arn    = aws_lb_target_group.project2.arn
}

resource "aws_security_group" "project2_instance" {
  name = "asg-project2-instance"
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.project2_lb.id]
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  vpc_id = module.vpc.vpc_id
}

resource "aws_security_group" "project2_lb" {
  name = "asg-project2-lb"
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = module.vpc.vpc_id
}
