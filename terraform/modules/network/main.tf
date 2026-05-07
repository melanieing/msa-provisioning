# ─────────────────────────────────────────────────────────────────────────
# modules/network — VPC + Subnet + IGW + NAT
# ─────────────────────────────────────────────────────────────────────────
# 클러스터의 네트워크 뼈대를 만든다.
#   - VPC 1개
#   - Subnet 4개 (public ×2 + private ×2, 두 AZ 에 분산)
#   - Internet Gateway 1개 (public 의 인터넷 출구)
#   - NAT Gateway 2개 + EIP 2개 (private 의 인터넷 출구, AZ 별)
#   - Route Table : public 1개 + private AZ 별 1개씩
# Security Group 은 'security' 모듈, NLB 는 'loadbalancer' 모듈에 따로 있음.
# ─────────────────────────────────────────────────────────────────────────


# ─── VPC ──────────────────────────────────────────────────────────
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
}


# ─── Internet Gateway ─────────────────────────────────────────────
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.this.id
}


# ─── Subnets (AZ A) ───────────────────────────────────────────────
resource "aws_subnet" "public_a" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.public_subnet_a_cidr
  availability_zone = var.az_a
  tags = {
    "kubernetes.io/role/elb" = "1" # AWS LBC 가 외부 ALB 만들 때 이 태그 봄
  }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_a_cidr
  availability_zone = var.az_a
  tags = {
    "kubernetes.io/role/internal-elb" = "1" # 내부 ALB 자동 생성용
  }
}


# ─── Subnets (AZ B) ───────────────────────────────────────────────
resource "aws_subnet" "public_b" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.public_subnet_b_cidr
  availability_zone = var.az_b
  tags = {
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_b_cidr
  availability_zone = var.az_b
  tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}


# ─── NAT Gateway (AZ A) ───────────────────────────────────────────
resource "aws_eip" "nat_a" {
  domain = "vpc"
}

resource "aws_nat_gateway" "a" {
  allocation_id = aws_eip.nat_a.id
  subnet_id     = aws_subnet.public_a.id      # NAT 는 public subnet 에 둠
  depends_on    = [aws_internet_gateway.main] # IGW 가 먼저
}


# ─── NAT Gateway (AZ B) ───────────────────────────────────────────
resource "aws_eip" "nat_b" {
  domain = "vpc"
}

resource "aws_nat_gateway" "b" {
  allocation_id = aws_eip.nat_b.id
  subnet_id     = aws_subnet.public_b.id
  depends_on    = [aws_internet_gateway.main]
}


# ─── Public Route Table (두 AZ 의 public subnet 공용) ─────────────
# 0.0.0.0/0 → IGW. 즉 public subnet 의 모든 외부 트래픽은 IGW 로.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}


# ─── Private Route Table (AZ A) ───────────────────────────────────
# 0.0.0.0/0 → 같은 AZ 의 NAT Gateway. AZ 마다 따로 둠 (NAT 가 다르기 때문).
resource "aws_route_table" "private_a" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.a.id
  }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private_a.id
}


# ─── Private Route Table (AZ B) ───────────────────────────────────
resource "aws_route_table" "private_b" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.b.id
  }
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private_b.id
}
