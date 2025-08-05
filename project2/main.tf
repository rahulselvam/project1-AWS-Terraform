# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.common_tags
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.0.1"

  name = "${var.project_name}-${var.environment}-vpc"
  cidr = var.vpc_cidr

  azs                  = data.aws_availability_zones.available.names
  public_subnets       = var.public_subnets
  private_subnets      = var.private_subnets
  database_subnets     = var.database_subnets
  create_database_subnet_group = true
  enable_nat_gateway   = var.enable_nat_gateway
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
    values = [var.ami_name]
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
  name_prefix     = "${var.project_name}-${var.environment}-asg-"
  image_id        = data.aws_ami.amazon_linux.id
  instance_type   = var.instance_type
  key_name        = var.key_pair_name != "" ? var.key_pair_name : null
  user_data       = filebase64("${path.module}/user-data.sh")
  vpc_security_group_ids = [aws_security_group.project2_instance.id]
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "project2" {
  name             = "${var.project_name}-${var.environment}-asg"
  min_size         = var.asg_min_size
  max_size         = var.asg_max_size
  desired_capacity = var.asg_desired_capacity
  launch_template {
    id      = aws_launch_template.project2.id
    version = "$Latest"
  }
  vpc_zone_identifier  = module.vpc.private_subnets
  #vpc_zone_identifier  = module.vpc.public_subnets

  health_check_type    = "ELB"

  tag {
    key                 = "Name"
    value               = "${var.project_name}-${var.environment}-instance"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = var.common_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

resource "aws_lb" "project2" {
  name               = "${var.project_name}-${var.environment}-lb"
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
  name     = "${var.project_name}-${var.environment}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
}


resource "aws_autoscaling_attachment" "project2" {
  autoscaling_group_name = aws_autoscaling_group.project2.id
  lb_target_group_arn    = aws_lb_target_group.project2.arn
}

resource "aws_security_group" "project2_instance" {
  name = "${var.project_name}-${var.environment}-instance-sg"
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
  name = "${var.project_name}-${var.environment}-lb-sg"
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

resource "aws_security_group" "rds" {
  name = "${var.project_name}-${var.environment}-rds-sg"
  
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.project2_instance.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = module.vpc.vpc_id
}

resource "aws_db_instance" "main" {
  identifier     = "${var.project_name}-${var.environment}-db"
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = var.db_instance_class
  allocated_storage = var.db_allocated_storage
  
  db_name  = var.db_name
  username = var.db_username
  manage_master_user_password = var.manage_master_user_password
  
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = module.vpc.database_subnet_group
  
  skip_final_snapshot = true
  
  tags = {
    Name = "${var.project_name}-${var.environment}-database"
  }
}
