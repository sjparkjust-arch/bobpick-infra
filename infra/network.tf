# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "bobpick-vpc"
  }
}

# Public Subnets
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block               = "10.0.1.0/24"
  availability_zone        = "ap-northeast-2a"
  map_public_ip_on_launch  = true

  tags = {
    Name = "bobpick-public-a"
  }
}

resource "aws_subnet" "public_c" {
  vpc_id                  = aws_vpc.main.id
  cidr_block               = "10.0.2.0/24"
  availability_zone        = "ap-northeast-2c"
  map_public_ip_on_launch  = true

  tags = {
    Name = "bobpick-public-c"
  }
}

# Private App Subnets
resource "aws_subnet" "private_app_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = "ap-northeast-2a"

  tags = {
    Name = "bobpick-private-app-a"
  }
}

resource "aws_subnet" "private_app_c" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.20.0/24"
  availability_zone = "ap-northeast-2c"

  tags = {
    Name = "bobpick-private-app-c"
  }
}

# Private DB Subnets
resource "aws_subnet" "private_db_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.100.0/24"
  availability_zone = "ap-northeast-2a"

  tags = {
    Name = "bobpick-private-db-a"
  }
}

resource "aws_subnet" "private_db_c" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.200.0/24"
  availability_zone = "ap-northeast-2c"

  tags = {
    Name = "bobpick-private-db-c"
  }
}