
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      #version = "~> 4.16"
    }
  }
  required_version = ">= 1.2.0"
}

provider "aws" {
  #version = "~> 4.66"
  region = "us-east-1"
}


#creating a vpc 
resource "aws_vpc" "my-vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "my-vpc"
  }
}
#create internet gateway
resource "aws_internet_gateway" "My_igw" {
  vpc_id = aws_vpc.my-vpc.id

  tags = {
    Name = "IGW"
  }
}


#create rout table 
resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.my-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.My_igw.id
  }
  tags = {
    Name = "public route table"
  }
}

#associate route table to subnet
resource "aws_route_table_association" "public_route_table_association" {
  subnet_id      = aws_subnet.my-subnet.id
  route_table_id = aws_route_table.route_table.id
}
#Creating a subnet
resource "aws_subnet" "my-subnet" {
  vpc_id                  = aws_vpc.my-vpc.id
  availability_zone       = "us-east-1a"
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "My-Subnet"
  }

}


resource "aws_instance" "My_instance" {
  ami                    = "ami-090e0fc566929d98b"
  instance_type          = "t2.medium"
  availability_zone      = "us-east-1a"
  key_name               = aws_key_pair.gen_key_pair.key_name
  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]
  subnet_id              = aws_subnet.my-subnet.id
  connection {
    type      = "ssh"
    user      = "ec2-user"
    host      = self.public_ip
    user_data = file("${path.module}/userdata.sh")
    #private_key  = file("~/terraform-scripts/exercise1/aws_key_pair.pem" )

  }

  associate_public_ip_address = true


  user_data = file("${path.module}/userdata.sh")
  #user_data_replace_on_change = true

  tags = {
    Name      = "Dove-Instance"
    terraform = "true"
  }
}
#network interface
resource "aws_network_interface" "test" {
  subnet_id = aws_subnet.my-subnet.id
  #private_ips = ["0.0.0.0/0"]
  security_groups = ["${aws_security_group.jenkins_sg.id}"]
  attachment {
    instance     = aws_instance.My_instance.id
    device_index = 1
  }
}

#automatically generated key 'gen_tls_pk':
resource "tls_private_key" "gen_tls_pk" {
  algorithm = "RSA"
  rsa_bits  = 4096

}
#automatically generated key-pair 'gen_key_pair'
resource "aws_key_pair" "gen_key_pair" {
  key_name   = var.key_pair_name
  public_key = tls_private_key.gen_tls_pk.public_key_openssh
}
#File to save .pem key to:
resource "local_file" "key_local_file" {
  content  = tls_private_key.gen_tls_pk.private_key_pem
  filename = var.key_file
}
# Security Group
resource "aws_security_group" "jenkins_sg" {
  vpc_id = aws_vpc.my-vpc.id
  name   = "jenkins_sg"


  #Allow incoming TCP requests on port 22 from any IP
  ingress {
    description      = "Incoming SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  #Allow incoming TCP requests on port 8080 from any IP
  ingress {
    description = "Incoming 8080"
    from_port   = 8080
    to_port     = 8080

    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  #Allow incoming TCP requests on port 443 from any IP
  ingress {
    description      = "Incoming 443"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  #Allow all outbound requests
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "jenkins_sg"
  }


}



