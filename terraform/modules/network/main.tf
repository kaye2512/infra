resource "aws_vpc" "main_vpc" {
  cidr_block = var.vpc_cidr_block
  enable_dns_hostnames = true

  tags = {
    Name = "main-vpc"
  }
}

resource "aws_subnet" "public_subnet" {
  for_each = toset(var.availability_zones)
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = var.public_subnet_cidr[index(var.availability_zones, each.value)]
  availability_zone = each.value
  map_public_ip_on_launch = true

  tags = {
    Name = "public-${each.value}"
  }
}

resource "aws_subnet" "private_subnet" {
  for_each = toset(var.availability_zones)
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = var.private_subnet_cidr[index(var.availability_zones, each.value)]
  availability_zone = each.value
  tags = {
    Name = "private-${each.value}"
  }
}

resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }

}

resource "aws_route_table_association" "public_subnet_association" {
  for_each = aws_subnet.public_subnet
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "private_subnet_association" {
  for_each = aws_subnet.private_subnet
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "nat-eip"
  }
}

resource "aws_nat_gateway" "main_nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet[var.availability_zones[0]].id

  tags = {
    Name = "main-nat"
  }

  depends_on = [aws_internet_gateway.main_igw]
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main_nat.id
  }
}

