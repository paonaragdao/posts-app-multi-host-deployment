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
}

provider "aws" {
  region = "us-east-1"
}

#
# Shared resources e.g. AMI, ssh keypair, security group
#

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

# Posts-App
resource "aws_instance" "posts" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.admin.key_name
  vpc_security_group_ids = [aws_security_group.posts_sg.id]
  user_data = <<-EOF
                #!/bin/bash
                apt-get update -y
                apt-get install -y python3 python3-apt
                EOF
  tags = { Name = "posts-section-a" }
}

output "public_ip" {
  value = aws_instance.posts.public_ip
}

# Security group

resource "aws_security_group" "posts_sg" {
  name = "posts-app-sg"
  description = "Allow SSH and HTTP"
    vpc_id = data.aws_vpc.default.id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP in
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS out
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_vpc" "default" {
  default = true
}