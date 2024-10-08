# VPC resource
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = merge(
    local.default_tags,
    {
      Name = "main-vpc"
    }
  )
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = merge(
    local.default_tags,
    {
      Name = "main-igw"
    }
  )
}

# Subnets
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = true
  tags = merge(
    local.default_tags,
    {
      Name = "Public Subnet"
    }
  )
}

resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "eu-central-1a"
  tags = merge(
    local.default_tags,
    {
      Name = "Private Subnet"
    }
  )
}
# commented for cost saving
# # NAT Gateway
# resource "aws_eip" "nat_1" {
#   domain = "vpc"
# }

# resource "aws_nat_gateway" "gw_1" {
#   allocation_id = aws_eip.nat_1.id
#   subnet_id     = aws_subnet.public_1.id
# }

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = merge(
    local.default_tags,
    {
      Name = "Public Route Table"
    }
  )
}

resource "aws_route_table" "private_1" {
  vpc_id = aws_vpc.main.id
  # commented for cost saving
  # route {
  #   cidr_block     = "0.0.0.0/0"
  #   nat_gateway_id = aws_nat_gateway.gw_1.id
  # }
  tags = merge(
    local.default_tags,
    {
      Name = "Private Route Table"
    }
  )
}

# Route Table Associations
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private_1.id
}

# Security Group
resource "aws_security_group" "allow_internal" {
  name        = "allow_internal"
  description = "Allow all internal VPC traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "All traffic within VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.default_tags,
    {
      Name = "allow_internal"
    }
  )
}

# VPC Endpoint for DynamoDB
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.eu-central-1.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids = [
    aws_route_table.public.id,
    aws_route_table.private_1.id
  ]
  tags = merge(
    local.default_tags,
    {
      Name = "DynamoDB VPC Endpoint"
    }
  )
}

resource "aws_vpc_endpoint" "lambda" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.eu-central-1.lambda"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_1.id]
  security_group_ids  = [aws_security_group.allow_internal.id]
  private_dns_enabled = true
  tags = merge(
    local.default_tags,
    {
      Name = "Lambda VPC Endpoint"
    }
  )
}