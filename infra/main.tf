#
# Providers etc
#

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    bucket  = "s3939218-tfstate"
    key     = "assignment2/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}

provider "aws" {
  region = "us-east-1"
}

#
# Shared resources (AMI, SSH keypair, VPC/Subnets)
#

data "aws_vpc" "default" {
  default = true
}

# Default VPC Subnets (used by ALBs)
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_key_pair" "admin" {
  key_name   = "admin-keyfor-assignment2"
  public_key = file(var.path_to_ssh_public_key)
}

#
# Security Groups
#

# --- ALB SGs ---
resource "aws_security_group" "frontend_alb_sg" {
  name        = "posts-frontend-alb-sg"
  description = "Allow HTTP 80 from Internet to Frontend ALB"
  vpc_id      = data.aws_vpc.default.id

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
}

resource "aws_security_group" "backend_alb_sg" {
  name        = "posts-backend-alb-sg"
  description = "Allow HTTP 80 from Internet to Backend ALB"
  vpc_id      = data.aws_vpc.default.id

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
}

# --- Instance SGs ---
# Frontend Instances SG
resource "aws_security_group" "frontend_sg" {
  name        = "posts-frontend-sg"
  description = "Allow 8081 from Frontend ALB and SSH"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = 8081
    to_port         = 8081
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend_alb_sg.id]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Backend Instances SG
resource "aws_security_group" "backend_sg" {
  name        = "posts-backend-sg"
  description = "Allow 80 from Backend ALB and SSH"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.backend_alb_sg.id]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# DB SG
resource "aws_security_group" "db_sg" {
  name        = "posts-db-sg"
  description = "Allow Postgres from Backend hosts and SSH"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.backend_sg.id]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#
# EC2 instances
#

# DB host
resource "aws_instance" "db" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.admin.key_name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y python3 python3-apt
              EOF
  tags = { Name = "posts-db" }
}

# Backend Hosts
resource "aws_instance" "backend_a" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.admin.key_name
  vpc_security_group_ids = [aws_security_group.backend_sg.id]
  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y python3 python3-apt
              EOF
  tags = { Name = "posts-backend-a" }
}

resource "aws_instance" "backend_b" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.admin.key_name
  vpc_security_group_ids = [aws_security_group.backend_sg.id]
  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y python3 python3-apt
              EOF
  tags = { Name = "posts-backend-b" }
}

# Frontend Hosts
resource "aws_instance" "frontend_a" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.admin.key_name
  vpc_security_group_ids = [aws_security_group.frontend_sg.id]
  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y python3 python3-apt
              EOF
  tags = { Name = "posts-frontend-a" }
}

resource "aws_instance" "frontend_b" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.admin.key_name
  vpc_security_group_ids = [aws_security_group.frontend_sg.id]
  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y python3 python3-apt
              EOF
  tags = { Name = "posts-frontend-b" }
}

#
# Application Load Balancers
#

# Backend ALB
resource "aws_lb" "backend_alb" {
  name               = "posts-backend-alb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.backend_alb_sg.id]
  subnets            = data.aws_subnets.default.ids
}

resource "aws_lb_target_group" "backend_tg" {
  name     = "posts-backend-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id
  health_check {
    path = "/"
  }
}

resource "aws_lb_target_group_attachment" "backend_a" {
  target_group_arn = aws_lb_target_group.backend_tg.arn
  target_id        = aws_instance.backend_a.id
  port             = 80
}
resource "aws_lb_target_group_attachment" "backend_b" {
  target_group_arn = aws_lb_target_group.backend_tg.arn
  target_id        = aws_instance.backend_b.id
  port             = 80
}

resource "aws_lb_listener" "backend_http" {
  load_balancer_arn = aws_lb.backend_alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_tg.arn
  }
}

# Frontend ALB
resource "aws_lb" "frontend_alb" {
  name               = "posts-frontend-alb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.frontend_alb_sg.id]
  subnets            = data.aws_subnets.default.ids
}

resource "aws_lb_target_group" "frontend_tg" {
  name     = "posts-frontend-tg-8081"
  port     = 8081
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id
  health_check {
    path = "/"
  }



  lifecycle { create_before_destroy = true }
}

resource "aws_lb_target_group_attachment" "frontend_a" {
  target_group_arn = aws_lb_target_group.frontend_tg.arn
  target_id        = aws_instance.frontend_a.id
  port             = 8081
}
resource "aws_lb_target_group_attachment" "frontend_b" {
  target_group_arn = aws_lb_target_group.frontend_tg.arn
  target_id        = aws_instance.frontend_b.id
  port             = 8081
}

resource "aws_lb_listener" "frontend_http" {
  load_balancer_arn = aws_lb.frontend_alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_tg.arn
  }
}

#
# Outputs
#


output "db_ip" {
  value = aws_instance.db.public_ip
}

output "frontend_a_ip" { 
  value = aws_instance.frontend_a.public_ip 
}
output "frontend_b_ip" { 
  value = aws_instance.frontend_b.public_ip 
}
output "backend_a_ip"  { 
  value = aws_instance.backend_a.public_ip 
}
output "backend_b_ip"  { 
  value = aws_instance.backend_b.public_ip 
}

output "backend_alb_dns" {
  value = aws_lb.backend_alb.dns_name
}
output "frontend_alb_dns" {
  value = aws_lb.frontend_alb.dns_name
}
