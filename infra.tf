provider "aws" {
  region = "us-east-2"
  profile= "default"
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "TaskVPC" {
  cidr_block       = "192.168.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames= true
  enable_dns_support   = true

  tags = {
    Name = "TaskVPC"
  }
}

resource "aws_security_group" "public_sg" {
  name        = "wordpress"
  description = "Allow TLS inbound traffic"
  vpc_id      = "${aws_vpc.TaskVPC.id}"


ingress {
    from_port = -1
    to_port = -1
    protocol = "icmp"
    cidr_blocks = [aws_vpc.TaskVPC.cidr_block]
  }

 ingress {
    
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 ingress {
    
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 ingress {
    
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = {
    Name = "allow_tls"
  }
}

resource "aws_security_group" "private_sg" {
  name        = "mysql_sg"
  description = "Allow TLS inbound traffic"
  vpc_id      = "${aws_vpc.TaskVPC.id}"
  
 
ingress {
    
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["192.168.2.0/24"]
  }
ingress {
    from_port = -1
    to_port = -1
    protocol = "icmp"
    cidr_blocks = [aws_vpc.TaskVPC.cidr_block]
  }

ingress {
  from_port   = 3306
  to_port     = 3306
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

resource "aws_subnet" "public_subnet" {
  vpc_id     = "${aws_vpc.TaskVPC.id}"
  cidr_block = "192.168.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "publicsubnet"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id     = "${aws_vpc.TaskVPC.id}"
  cidr_block = "192.168.3.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]
  tags = {
    Name = "privatesubnet"
  }
}



resource "aws_internet_gateway" "igw1" {
  vpc_id = "${aws_vpc.TaskVPC.id}"

  tags = {
    Name = "igwTaskVPC"
  }
}

resource "aws_eip" "test-eip" {
  vpc = true
}

resource "aws_nat_gateway" "nat-gateway" {
  allocation_id = "${aws_eip.test-eip.id}"
  subnet_id     = "${aws_subnet.public_subnet.id}"
}


resource "aws_route_table" "public_route" {
  vpc_id = "${aws_vpc.TaskVPC.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.igw1.id}"
}

tags = {
    Name = "public-route-table"
  }
}
  

resource "aws_default_route_table" "private_route" {
  default_route_table_id = "${aws_vpc.TaskVPC.default_route_table_id}"

  route {
    nat_gateway_id = "${aws_nat_gateway.nat-gateway.id}"
    cidr_block     = "0.0.0.0/0"
  }

  tags = {
    Name = "private-route-table"
  }
}

resource "aws_route_table_association" "public_subnet_assoc" {
  route_table_id = "${aws_route_table.public_route.id}"
  subnet_id      = "${aws_subnet.public_subnet.id}"
  depends_on     = ["aws_route_table.public_route", "aws_subnet.public_subnet"]
}

resource "aws_route_table_association" "private_subnet_assoc" {
   route_table_id = "${aws_default_route_table.private_route.id}"
  subnet_id      = "${aws_subnet.private_subnet.id}"
  depends_on     = ["aws_default_route_table.private_route", "aws_subnet.private_subnet"]
}


resource "aws_instance" "mysql" {
  ami           = "ami-024e6efaf93d85776"
  instance_type = "t2.micro"
  vpc_security_group_ids = ["${aws_security_group.private_sg.id}"] 
  subnet_id     = "${aws_subnet.private_subnet.id}"
  key_name     =  "task"
 
 tags = {
  Name = "mysql"
  }
}

resource "aws_instance" "wordpress" {
  ami           = "ami-024e6efaf93d85776" 
  instance_type = "t2.micro"
  key_name     =  "task" 
  vpc_security_group_ids = ["${aws_security_group.public_sg.id}"] 
  subnet_id     = "${aws_subnet.public_subnet.id}"
  
  tags = {
  Name = "wordpress"
  }
  
}