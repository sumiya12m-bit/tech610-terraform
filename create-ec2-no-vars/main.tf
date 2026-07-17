# use aws provider
provider "aws" {
    region = "eu-west-1"
}


# create ec2 instance
# ami ami-0c1c30571d2dae5c9 (for ubuntu 22.04 lts)
# type t3.micro
# name "tech610-sumiya-tf-first-vm"
resource "aws_instance" "test_vm" {
  ami           = "ami-0c1c30571d2dae5c9"
  instance_type = "t3.micro"
  tags = {
    Name = "tech610-sumiya-tf-first-vm"
  }
}