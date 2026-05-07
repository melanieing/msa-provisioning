# ─────────────────────────────────────────────────────────────────────────
# 이 파일은 뭐 하는 파일?
# ─────────────────────────────────────────────────────────────────────────
# AZ B (ap-northeast-2b) 의 subnet 2개. 2a-subnet.tf 와 같은 구조의 거울 짝이야.
# 한 AZ 가 다운돼도 클러스터가 죽지 않게 분산 배치하려고 두 AZ 사용.
# ─────────────────────────────────────────────────────────────────────────


# public subnet (AZ B)
resource "aws_subnet" "public-ap-northeast-2b" {
  vpc_id            = aws_vpc.kt-cloud-vpc.id
  cidr_block        = var.public_subnet_b_cidr # 기본 10.0.3.0/24
  availability_zone = var.az_b
  tags = {
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_route_table_association" "public-2b-assoc" {
  subnet_id      = aws_subnet.public-ap-northeast-2b.id
  route_table_id = aws_route_table.kt-cloud-public-rt.id # public RT 는 두 AZ 공용
}


# private subnet (AZ B)
resource "aws_subnet" "private-ap-northeast-2b" {
  vpc_id            = aws_vpc.kt-cloud-vpc.id
  cidr_block        = var.private_subnet_b_cidr # 기본 10.0.4.0/24
  availability_zone = var.az_b
  tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# private RT 는 AZ 마다 다름 (각 AZ 의 NAT 로 보내야 해서)
resource "aws_route_table" "private-ap-northeast-2b-rt" {
  vpc_id = aws_vpc.kt-cloud-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.ap-northeast-2b-nat-gw.id
  }
}

resource "aws_route_table_association" "private-ap-northeast-2b-assoc" {
  subnet_id      = aws_subnet.private-ap-northeast-2b.id
  route_table_id = aws_route_table.private-ap-northeast-2b-rt.id
}
