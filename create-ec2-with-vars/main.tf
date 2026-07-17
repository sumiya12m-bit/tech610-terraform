# use aws provider
provider "aws" {
  region = "eu-west-1"
}

# create security group
resource "aws_security_group" "tech610_sumiya_tf_sg" {
  name        = "tech610-sumiya-tf-allow-port-22-3000-80"
  description = "Security group created by Terraform"
}

# fetch current public IP automatically
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

# allow port 22 from my IP only
resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  security_group_id = aws_security_group.tech610_sumiya_tf_sg.id
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = "${chomp(data.http.my_ip.response_body)}/32"
}

# allow port 3000 from all
resource "aws_vpc_security_group_ingress_rule" "allow_3000" {
  security_group_id = aws_security_group.tech610_sumiya_tf_sg.id
  from_port         = 3000
  to_port           = 3000
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

# allow port 80 from all
resource "aws_vpc_security_group_ingress_rule" "allow_http" {
  security_group_id = aws_security_group.tech610_sumiya_tf_sg.id
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

# allow all outbound traffic
resource "aws_vpc_security_group_egress_rule" "allow_all_outbound" {
  security_group_id = aws_security_group.tech610_sumiya_tf_sg.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# create ec2 instance
# ami ami-0c1c30571d2dae5c9 (for ubuntu 22.04 lts)
# type t3.micro
# name "tech610-sumiya-tf-first-vm"
resource "aws_instance" "test_vm" {
  ami                     = var.test_vm_ami_id
  instance_type           = "t3.micro"
  key_name                = var.key_name
  vpc_security_group_ids = [aws_security_group.tech610_sumiya_tf_sg.id]
  tags = {
    Name        = "tech610-sumiya-tf-first-vm"
    Environment = "test"
  }
}