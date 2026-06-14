terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

############################
# Providers
############################

provider "aws" {
  region = "eu-north-1"
}

provider "aws" {
  alias  = "ireland"
  region = "eu-west-1"
}

############################
# Security Groups
############################

resource "aws_security_group" "sg_stockholm" {
  name = "nginx-sg-stockholm"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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

resource "aws_security_group" "sg_ireland" {
  provider = aws.ireland
  name     = "nginx-sg-ireland"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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

############################
# Latest Amazon Linux 2023
############################

data "aws_ami" "amazon_linux_north" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

data "aws_ami" "amazon_linux_ireland" {
  provider    = aws.ireland
  most_recent = true

  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

############################
# EC2 in eu-north-1
############################

resource "aws_instance" "ec2_stockholm" {
  ami                    = data.aws_ami.amazon_linux_north.id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.sg_stockholm.id]

  user_data = <<-EOF
              #!/bin/bash
              dnf update -y
              dnf install nginx -y
              systemctl enable nginx
              systemctl start nginx

              echo "<h1>Nginx running in eu-north-1</h1>" > /usr/share/nginx/html/index.html
              EOF

  tags = {
    Name = "nginx-eu-north-1"
  }
}

############################
# EC2 in eu-west-1
############################

resource "aws_instance" "ec2_ireland" {
  provider               = aws.ireland
  ami                    = data.aws_ami.amazon_linux_ireland.id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.sg_ireland.id]

  user_data = <<-EOF
              #!/bin/bash
              dnf update -y
              dnf install nginx -y
              systemctl enable nginx
              systemctl start nginx

              echo "<h1>Nginx running in eu-west-1</h1>" > /usr/share/nginx/html/index.html
              EOF

  tags = {
    Name = "nginx-eu-west-1"
  }
}

############################
# Outputs
############################

output "stockholm_public_ip" {
  value = aws_instance.ec2_stockholm.public_ip
}

output "ireland_public_ip" {
  value = aws_instance.ec2_ireland.public_ip
}