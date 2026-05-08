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


# ─────────────────────────────────────────────────────────────────────────
# A6 — VPC Endpoint (PDF §5.1)
# ─────────────────────────────────────────────────────────────────────────
# VPC Endpoint = VPC 안에서 AWS 서비스로 가는 트래픽을 인터넷 대신 AWS 백본
#   망으로 보내는 사설 통로. NAT 비용 절약 + 보안 강화 (트래픽이 인터넷 안 탐).
#
# 두 종류:
#   1. Gateway Endpoint  — S3, DynamoDB 만 지원. 무료. Route Table 에 entry
#                          추가 형태. 본 프로젝트는 S3 (ECR 이미지 layer 가
#                          내부적으로 S3 에 저장됨, ECR pull 시 트래픽 절약).
#   2. Interface Endpoint — 거의 모든 AWS 서비스. AZ 마다 ENI 1개 = 시간당
#                          ~0.014 USD/AZ + 데이터 처리비. 본 프로젝트는 KMS
#                          (EFS 의 KMS 호출 + ECR 의 KMS 호출이 NAT 안 타도록).
#
# 비용:
#   - S3 gateway: 무료
#   - KMS interface ×2 AZ: 시간당 ~0.028 USD ≈ 38원/h. 9일 4h/일 운영 ≈ 1,400원
# ─────────────────────────────────────────────────────────────────────────


# ─── 현재 region 자동 조회 (provider 설정 따라옴) ─────────────────
data "aws_region" "current" {}


# ─── S3 Gateway Endpoint ──────────────────────────────────────────
# Route Table 에 'pl-xxxxxx (S3 prefix list)' → endpoint 라는 entry 자동 추가.
# 두 private RT 에 모두 attach (AZ A, AZ B 의 EC2 모두 사용 가능).
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.private_a.id,
    aws_route_table.private_b.id,
  ]
}


# ─── Interface Endpoint 전용 SG ───────────────────────────────────
# Interface endpoint 의 ENI 가 살 SG. VPC 안 자원에서 HTTPS(443) 인바운드 허용.
# (예: EC2 노드가 KMS API 호출 시 ENI 의 443 으로 들어옴)
resource "aws_security_group" "vpc_endpoint" {
  vpc_id      = aws_vpc.this.id
  name        = "vpc-endpoint-sg"
  description = "Allow HTTPS 443 from VPC for AWS service interface endpoints"

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "HTTPS from anywhere in VPC"
  }

  # Endpoint ENI 가 응답 보낼 때 필요. 보통 보수적이지만 endpoint 에서는 all egress 가 표준.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# ─── KMS Interface Endpoint ───────────────────────────────────────
# private_dns_enabled = true 로 두면 'kms.<region>.amazonaws.com' 이 자동으로
# endpoint ENI 의 사설 IP 로 resolve 됨. 그래서 EC2 의 AWS SDK 코드 변경 0.
resource "aws_vpc_endpoint" "kms" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.kms"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id,
  ]

  security_group_ids = [aws_security_group.vpc_endpoint.id]
}
