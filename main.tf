//variables.tf
variable "ami_key_pair_name" {
    default = "terraform"
}

variable "location" {
    type = object({
        region = string
        availability_zone = string
    })
    default = {
      region = "eu-central-1"
      availability_zone = "eu-central-1a"
    }
}

variable "instance_web" {
    type = object({
        type = string
        name = string
        ami  = string
    })
    default = {
      type = "t2.micro"
      name = "Terraform POC Instance"
      ami  = "ami-0cc0a36f626a4fdf5"
    }
}

variable "instance_name_1" {
    default = "Terraform POC Instance 1"
    description = "Name of webserver instance"
}

variable "instance_name_2" {
    default = "Terraform POC Instance 2"
    description = "Name of webserver instance"
}

variable "web_port" {
    default = "80"
    description = "Port on which web application is running"
}

//main.tf
provider "aws" {
  region = var.location.region
  version = "~> 2.41"
}

//gateways.tf
resource "aws_internet_gateway" "terraform-poc-igw" {
  vpc_id = aws_vpc.terraform-poc-vpc.id
  tags = {
    Name = "terraform-poc-igw"
  }
}

//network.tf
resource "aws_vpc" "terraform-poc-vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
  tags = {
    Name = "terraform-poc-vpc"
  }
}

resource "aws_eip" "terraform-poc-eip-1" {
  instance = aws_instance.terraform-poc-ec2-instance-1.id
  vpc      = true
}

resource "aws_eip" "terraform-poc-eip-2" {
  instance = aws_instance.terraform-poc-ec2-instance-2.id
  vpc      = true
}

resource "aws_lb_target_group" "terraform-poc-lb-target-group" {
  name     = "terraform-poc-lb-target-group"
  port     = 80
  protocol = "TCP"
  vpc_id   = aws_vpc.terraform-poc-vpc.id
}

resource "aws_lb_target_group_attachment" "terraform-poc-lb-target-attach-1" {
  target_group_arn = aws_lb_target_group.terraform-poc-lb-target-group.arn
  target_id        = aws_instance.terraform-poc-ec2-instance-1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "terraform-poc-lb-target-attach-2" {
  target_group_arn = aws_lb_target_group.terraform-poc-lb-target-group.arn
  target_id        = aws_instance.terraform-poc-ec2-instance-2.id
  port             = 80
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.terraform-poc-lb.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.terraform-poc-lb-target-group.arn
  }
}

resource "aws_lb" "terraform-poc-lb" {
  name               = "terraform-poc-lb"
  internal           = false
  load_balancer_type = "network"
  subnets            = [aws_subnet.terraform-poc-subnet-1.id]

  #enable_deletion_protection = true

  tags = {
    Name = "Terraform-lb"
  }
}

//subnets.tf

resource "aws_subnet" "terraform-poc-subnet-1" {
  cidr_block = cidrsubnet(aws_vpc.terraform-poc-vpc.cidr_block, 3, 1)
  vpc_id = aws_vpc.terraform-poc-vpc.id
  availability_zone = var.location.availability_zone
}


resource "aws_route_table" "terraform-poc-rt" {
  vpc_id = aws_vpc.terraform-poc-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.terraform-poc-igw.id
  }
  tags = {
    Name = "terraform-poc-rt"
  }
}
resource "aws_route_table_association" "subnet-association" {
  subnet_id      = aws_subnet.terraform-poc-subnet-1.id
  route_table_id = aws_route_table.terraform-poc-rt.id
}

//security.tf
resource "aws_security_group" "terraform-poc-sg"  {
name = "allow-all-sg"
vpc_id = aws_vpc.terraform-poc-vpc.id
ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 22
    to_port = 22
    protocol = "tcp"
  }
  
ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = var.web_port
    to_port = var.web_port
    protocol = "tcp"
}
  
  // Terraform removes the default rule
  egress {
   from_port = 0
   to_port = 0
   protocol = "-1"
   cidr_blocks = ["0.0.0.0/0"]
 }
    
}

//servers.tf
resource "aws_instance" "terraform-poc-ec2-instance-1" {
  ami = var.instance_web.ami
  instance_type = var.instance_web.type
  key_name = var.ami_key_pair_name
  vpc_security_group_ids = [aws_security_group.terraform-poc-sg.id]
  tags = {
    Name = var.instance_name_1
  }
  subnet_id = aws_subnet.terraform-poc-subnet-1.id
  
    user_data = <<-EOF
      #!/bin/bash
      sudo apt install apache2 -y
      echo "Terraform POC. <br> Node1" > /var/www/html/index.html
    EOF
}

resource "aws_instance" "terraform-poc-ec2-instance-2" {
  ami = var.instance_web.ami
  instance_type = var.instance_web.type
  key_name = var.ami_key_pair_name
  vpc_security_group_ids = [aws_security_group.terraform-poc-sg.id]
  tags = {
    Name = var.instance_name_2
  }
  subnet_id = aws_subnet.terraform-poc-subnet-1.id
  
    user_data = <<-EOF
      #!/bin/bash
      sudo apt install apache2 -y
      echo "Terraform POC. <br> Node 2" > /var/www/html/index.html
    EOF
}

output  "terraform-poc-ec2-instance-1-dns" {
    value = aws_eip.terraform-poc-eip-1.public_dns
}

output  "terraform-poc-ec2-instance-2-dns" {
    value = aws_eip.terraform-poc-eip-2.public_dns
}

output  "terraform-poc-lb-dns" {
    value = aws_lb.terraform-poc-lb.dns_name
}