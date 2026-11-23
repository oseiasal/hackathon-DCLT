data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs         = slice(data.aws_availability_zones.available.names, 0, var.az_count)
  name_prefix = "${var.project_name}-${var.environment}"
  nat_count   = var.single_nat_gateway ? 1 : var.az_count
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.name_prefix}-igw"
  }
}

# Tier 1: Subnets Públicas (ALB / NAT Gateway)
resource "aws_subnet" "public" {
  count = var.az_count

  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                                            = "${local.name_prefix}-public-${local.azs[count.index]}"
    Tier                                            = "public"
    "kubernetes.io/role/elb"                        = "1"
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }
}

# Tier 2: Subnets Privadas de Aplicação (Amazon EKS Worker Nodes)
resource "aws_subnet" "private_app" {
  count = var.az_count

  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = local.azs[count.index]

  tags = {
    Name                                            = "${local.name_prefix}-private-app-${local.azs[count.index]}"
    Tier                                            = "private-app"
    "kubernetes.io/role/internal-elb"               = "1"
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }
}

# Tier 3: Subnets Privadas de Dados (Amazon RDS & ElastiCache — sem acesso direto à internet)
resource "aws_subnet" "private_data" {
  count = var.az_count

  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 20)
  availability_zone = local.azs[count.index]

  tags = {
    Name = "${local.name_prefix}-private-data-${local.azs[count.index]}"
    Tier = "private-data"
  }
}

# NAT Gateway (single_nat_gateway = true em dev para controle de custos FinOps)
resource "aws_eip" "nat" {
  count  = local.nat_count
  domain = "vpc"

  tags = {
    Name = "${local.name_prefix}-nat-eip-${count.index + 1}"
  }
}

resource "aws_nat_gateway" "this" {
  count = local.nat_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${local.name_prefix}-nat-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.this]
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${local.name_prefix}-rt-public"
  }
}

resource "aws_route_table_association" "public" {
  count          = var.az_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private_app" {
  count  = var.az_count
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[var.single_nat_gateway ? 0 : count.index].id
  }

  tags = {
    Name = "${local.name_prefix}-rt-private-app-${local.azs[count.index]}"
  }
}

resource "aws_route_table_association" "private_app" {
  count          = var.az_count
  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private_app[count.index].id
}

resource "aws_route_table" "private_data" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.name_prefix}-rt-private-data"
  }
}

resource "aws_route_table_association" "private_data" {
  count          = var.az_count
  subnet_id      = aws_subnet.private_data[count.index].id
  route_table_id = aws_route_table.private_data.id
}

# Security Groups (Zero-Trust)
resource "aws_security_group" "eks_nodes" {
  name        = "${local.name_prefix}-sg-eks-nodes"
  description = "Security Group base para worker nodes do EKS"
  vpc_id      = aws_vpc.this.id

  egress {
    description = "Trafego interno dentro da VPC (RDS, ElastiCache, DNS, controle EKS)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  # trivy:ignore:AVD-AWS-0104 -- Worker nodes em subnets privadas precisam de saida HTTPS (443) via NAT Gateway para ECR e APIs AWS (SQS, DynamoDB, SSM, Secrets Manager).
  egress {
    description = "Saida HTTPS (443) via NAT Gateway para ECR e APIs AWS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-sg-eks-nodes"
  }
}

resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-sg-rds"
  description = "Permite PostgreSQL (5432) apenas dos worker nodes do EKS"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "PostgreSQL a partir dos nodes EKS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
  }

  tags = {
    Name = "${local.name_prefix}-sg-rds"
  }
}

resource "aws_security_group" "elasticache" {
  name        = "${local.name_prefix}-sg-elasticache"
  description = "Permite Redis (6379) apenas dos worker nodes do EKS"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "Redis a partir dos nodes EKS"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
  }

  tags = {
    Name = "${local.name_prefix}-sg-elasticache"
  }
}
