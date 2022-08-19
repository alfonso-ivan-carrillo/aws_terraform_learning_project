#main.tf
# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
  access_key = var.access_key
  secret_key = var.secret_access_key
}

# resource "<provider>_<resource_type>" "name" {
#     config options.....
#     key = "value"
#     key2 = "another value"
# } 

# VPCv
resource "aws_vpc" "first-vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "Terraform VPC"
  }
}

# IGW
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.first-vpc.id

  tags = {
    Name = "terraformIGW"
  }
}

#Route Table
resource "aws_route_table" "terraformRT" {
  vpc_id = aws_vpc.first-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  # route {
  #   ipv6_cidr_block        = "::/0"
  #   egress_only_gateway_id = aws_internet_gateway.gw.id
  # }

  tags = {
    Name = "terraformRT"
  }
}


#Subnet
resource "aws_subnet" "subnet-1" {
  vpc_id     = aws_vpc.first-vpc.id   
  # vpc_id is not yet created but can be referenced by adding resource.nameOfResource.id = aws_vpc.first-vpc.id 
  # so once its created it will be referrenced by the code
  cidr_block = var.subnet_prefix
  availability_zone = "us-east-1a"

  tags = {
    Name = "terraform-subnet-1"
  }
}

#Route Table Association
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.terraformRT.id
} 

#Security Group
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web traffic"
  vpc_id      = aws_vpc.first-vpc.id 

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    # ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

#Network Interface
resource "aws_network_interface" "web-server" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
}

resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.gw]
}

#EC2
resource "aws_instance" "firstEc2" {
  ami = "ami-090fa75af13c156b4"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "myNVirginiaKeyPair"

  
  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.web-server.id
  }
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              amazon-linux-extras install -y lamp-mariadb10.2-php7.2 php7.2
              yum install -y httpd mariadb-server
              systemctl start httpd
              systemctl enable httpd
              usermod -a -G apache ec2-user
              chown -R ec2-user:apache /var/www
              chmod 2775 /var/www
              find /var/www -type d -exec chmod 2775 {} \;
              find /var/www -type f -exec chmod 0664 {} \;
              echo "<?php phpinfo(); ?>" > /var/www/html/phpinfo.php
              EOF
    tags = {
      Name = "web-server"
    }
}


