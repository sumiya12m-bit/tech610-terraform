# use aws provider
provider "aws" {
  region = var.region
}

# fetch current public IP automatically
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

# create app security group
resource "aws_security_group" "app_sg" {
  name        = var.app_sg_name
  description = "Security group for TicTacToe app VM"

  tags = {
    Name = var.app_sg_name
  }
}

# allow SSH from my IP only
resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  security_group_id = aws_security_group.app_sg.id
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = "${chomp(data.http.my_ip.response_body)}/32"
}

# allow port 80 from all
resource "aws_vpc_security_group_ingress_rule" "allow_http" {
  security_group_id = aws_security_group.app_sg.id
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

# allow port 3000 from all
resource "aws_vpc_security_group_ingress_rule" "allow_3000" {
  security_group_id = aws_security_group.app_sg.id
  from_port         = 3000
  to_port           = 3000
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

# allow all outbound traffic
resource "aws_vpc_security_group_egress_rule" "allow_all_outbound" {
  security_group_id = aws_security_group.app_sg.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# create app VM
resource "aws_instance" "app_vm" {
  ami                    = var.app_ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.app_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              export MONGODB_URI=mongodb://${aws_instance.db_vm.private_ip}:27017/tic-tac-toe
              cd /tech610-tic-tac-toe/app
              pm2 start index.js
              EOF

  tags = {
    Name = var.app_instance_name
  }
}

# create DB security group
resource "aws_security_group" "db_sg" {
  name        = var.db_sg_name
  description = "Security group for TicTacToe DB VM"

  tags = {
    Name = var.db_sg_name
  }
}

# allow SSH from my IP only
resource "aws_vpc_security_group_ingress_rule" "db_allow_ssh" {
  security_group_id = aws_security_group.db_sg.id
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = "${chomp(data.http.my_ip.response_body)}/32"
}

# allow MongoDB from anywhere
resource "aws_vpc_security_group_ingress_rule" "db_allow_mongodb" {
  security_group_id = aws_security_group.db_sg.id
  from_port         = 27017
  to_port           = 27017
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

# allow all outbound traffic
resource "aws_vpc_security_group_egress_rule" "db_allow_all_outbound" {
  security_group_id = aws_security_group.db_sg.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# create DB VM
resource "aws_instance" "db_vm" {
  ami                    = var.db_ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.db_sg.id]

  tags = {
    Name = var.db_instance_name
  }
}

# output the public IP so can visit it easily
output "app_public_ip" {
  value = aws_instance.app_vm.public_ip
}

output "db_private_ip" {
  value = aws_instance.db_vm.private_ip
}