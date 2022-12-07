#creating vpc
resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "main-vpc"
  }

}

#getting AZs
data "aws_availability_zones" "az" {
  state = "available"
}

#Creating 1st public subnet
resource "aws_subnet" "subnet1-pub" {
  availability_zone = data.aws_availability_zones.az.names[0]
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.1.0/24"
}

#Creating 2nd public subnet
resource "aws_subnet" "subnet2-pub" {
  vpc_id            = aws_vpc.vpc.id
  availability_zone = data.aws_availability_zones.az.names[1]
  cidr_block        = "10.0.2.0/24"
}

#Creating private subnet
resource "aws_subnet" "subnet-priv" {
  vpc_id            = aws_vpc.vpc.id
  availability_zone = data.aws_availability_zones.az.names[0]
  cidr_block        = "10.0.3.0/24"
}

#Creating 2nd private subnet
resource "aws_subnet" "subnet2-priv" {
  vpc_id            = aws_vpc.vpc.id
  availability_zone = data.aws_availability_zones.az.names[1]
  cidr_block        = "10.0.4.0/24"
}


#Creating IGW
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
}

#Creating NAT gw for instances in Private subnet

resource "aws_eip" "nat-ip" {
  vpc        = true
  depends_on = [aws_internet_gateway.igw]

}

resource "aws_nat_gateway" "ngw" {
  allocation_id = aws_eip.nat-ip.id
  subnet_id     = aws_subnet.subnet1-pub.id
  tags = {
    Name = "NAT-gw"
  }
}


#Adding internet route to default main route table
resource "aws_default_route_table" "main" {
  default_route_table_id = aws_vpc.vpc.default_route_table_id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "main-default-route"
  }
}

#Creating a route table for private subnet
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ngw.id
  }

  tags = {
    Name = "private-subnet-route"
  }
}

#Associating subnets to their route tables
resource "aws_route_table_association" "sub1" {
  subnet_id      = aws_subnet.subnet1-pub.id
  route_table_id = aws_default_route_table.main.id
}

resource "aws_route_table_association" "sub2" {
  subnet_id      = aws_subnet.subnet2-pub.id
  route_table_id = aws_default_route_table.main.id
}

resource "aws_route_table_association" "subpriv" {
  subnet_id      = aws_subnet.subnet-priv.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "sub2priv" {
  subnet_id      = aws_subnet.subnet2-priv.id
  route_table_id = aws_route_table.private.id
}



#Creating SG for LB, only TCP/80 inbound access from anywhere
resource "aws_security_group" "lb-sg" {
  name        = "lb-sg"
  description = "Allow all http traffic to LB"
  vpc_id      = aws_vpc.vpc.id
  ingress {
    description = "Allow 80 from anywhere"
    from_port   = 80
    to_port     = 80
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

#Creating SG for Jump Server in DMZ, ssh from specific IP 
resource "aws_security_group" "dmz-sg" {
  name        = "dmz-sg"
  description = "Allow ssh"
  vpc_id      = aws_vpc.vpc.id
  ingress {
    description = "Allow ssh from specific IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.external_ip]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Creating SG for instances in Private subnet Allow ssh from dmz, allow lb traffic, allow all traffic from self
resource "aws_security_group" "priv-sg" {
  name        = "priv-sg"
  description = "Allow all traffic from DMZ SG"
  vpc_id      = aws_vpc.vpc.id
  ingress {
    description     = "Allow all traffic from dmz"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.dmz-sg.id]
  }

  ingress {
    description     = "Allow all traffic to backend servers from alb"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.lb-sg.id]
  }

  ingress {
    description = "Allow all from private subnet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

