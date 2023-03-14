# Network Components
resource "aws_vpc" "vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
  tags = {
    "Name" = "${var.project_name}_vpc"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-west-2a"
  tags = {
    "Name" = "${var.project_name}_public_subnet"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-west-2a"
  tags = {
    "Name" = "${var.project_name}_private_subnet"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    "Name" = "${var.project_name}_igw"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    "Name" = "${var.project_name}_public_rt"
  }
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }
  tags = {
    "Name" = "${var.project_name}_private_rt"
  }
}

resource "aws_route_table_association" "public_subnet_to_rt" {
  route_table_id = aws_route_table.public_route_table.id
  subnet_id      = aws_subnet.public_subnet.id
}

resource "aws_route_table_association" "private_subnet_to_rt" {
  route_table_id = aws_route_table.private_route_table.id
  subnet_id      = aws_subnet.private_subnet.id
}

resource "aws_route_table_association" "public_subnet_to_private_rt" {
  route_table_id = aws_route_table.private_route_table.id
  subnet_id      = aws_subnet.public_subnet.id
}


resource "aws_security_group" "security_group" {
  name   = "${var.project_name}_security_group"
  vpc_id = aws_vpc.vpc.id

  egress {
    description = "All traffic"
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Name" = "${var.project_name}_security_group"
  }
}

resource "aws_eip" "eip" {
  vpc = true
  # instance = aws_instance.private_instance.id
  tags = {
    "Name" = "${var.project_name}_eip"
  }
}

# Make sure to atach NAT gateway to public subnet
resource "aws_nat_gateway" "nat_gateway" {
  subnet_id         = aws_subnet.public_subnet.id
  connectivity_type = "public"
  allocation_id     = aws_eip.eip.allocation_id
  tags = {
    "Name" = "${var.project_name}_nat_gateway"
  }
}

# EC2 Instances Components

resource "aws_key_pair" "key" {
  key_name   = "${var.project_name}_hadoop_key"
  public_key = file("~/.ssh/hadoop-key.pub")
}

resource "aws_instance" "public_instance" {
  ami                         = data.aws_ami.ubuntu_22_04.id
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.key.key_name
  user_data_replace_on_change = false
  associate_public_ip_address = true
  availability_zone           = "us-west-2a"
  subnet_id                   = aws_subnet.public_subnet.id
  vpc_security_group_ids      = [aws_security_group.security_group.id]
  tags = {
    "Name" = "${var.project_name}_public_instance"
  }
}

resource "aws_instance" "private_instance" {
  ami                         = data.aws_ami.ubuntu_22_04.id
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.key.key_name
  user_data_replace_on_change = false
  associate_public_ip_address = true
  availability_zone           = "us-west-2a"
  subnet_id                   = aws_subnet.private_subnet.id
  vpc_security_group_ids      = [aws_security_group.security_group.id]
  tags = {
    "Name" = "${var.project_name}_private_instance"
  }
}
