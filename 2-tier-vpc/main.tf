# use aws provider
provider "aws" {
  region = var.region
}

# fetch current public IP automatically
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

# ── VPC 
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = var.vpc_name
  }
}

# ── SUBNETS 
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = "eu-west-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "tech610-sumiya-tf-public-subnet"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = "eu-west-1b"

  tags = {
    Name = "tech610-sumiya-tf-private-subnet"
  }
}

# ── INTERNET GATEWAY 
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "tech610-sumiya-tf-igw"
  }
}

# ── PUBLIC ROUTE TABLE 
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "tech610-sumiya-tf-public-rt"
  }
}

# associate public route table with public subnet
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# APP SECURITY GROUP 
resource "aws_security_group" "app_sg" {
  name        = "tech610-sumiya-tf-vpc-app-sg"
  description = "Security group for app VM in custom VPC"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "tech610-sumiya-tf-vpc-app-sg"
  }
}

# allow SSH from my IP only
resource "aws_vpc_security_group_ingress_rule" "app_allow_ssh" {
  security_group_id = aws_security_group.app_sg.id
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = "${chomp(data.http.my_ip.response_body)}/32"
}

# allow port 80 from all
resource "aws_vpc_security_group_ingress_rule" "app_allow_http" {
  security_group_id = aws_security_group.app_sg.id
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

# allow port 3000 from all
resource "aws_vpc_security_group_ingress_rule" "app_allow_3000" {
  security_group_id = aws_security_group.app_sg.id
  from_port         = 3000
  to_port           = 3000
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

# allow all outbound
resource "aws_vpc_security_group_egress_rule" "app_allow_outbound" {
  security_group_id = aws_security_group.app_sg.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# DB SECURITY GROUP 
resource "aws_security_group" "db_sg" {
  name        = "tech610-sumiya-tf-vpc-db-sg"
  description = "Security group for DB VM in custom VPC"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "tech610-sumiya-tf-vpc-db-sg"
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

# allow MongoDB from public subnet only ← higher security
resource "aws_vpc_security_group_ingress_rule" "db_allow_mongodb" {
  security_group_id = aws_security_group.db_sg.id
  from_port         = 27017
  to_port           = 27017
  ip_protocol       = "tcp"
  cidr_ipv4         = var.public_subnet_cidr
}

# allow all outbound
resource "aws_vpc_security_group_egress_rule" "db_allow_outbound" {
  security_group_id = aws_security_group.db_sg.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# DB VM 
resource "aws_instance" "db_vm" {
  ami                    = var.db_ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.db_sg.id]

  tags = {
    Name = var.db_instance_name
  }
}

# APP VM 
resource "aws_instance" "app_vm" {
  ami                    = var.app_ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.public_subnet.id
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

# OUTPUTS 
output "app_public_ip" {
  value = aws_instance.app_vm.public_ip
}

output "db_private_ip" {
  value = aws_instance.db_vm.private_ip
}