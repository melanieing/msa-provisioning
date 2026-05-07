# ─────────────────────────────────────────────────────────────────────────
# 이 파일은 뭐 하는 파일?
# ─────────────────────────────────────────────────────────────────────────
# AZ A (ap-northeast-2a) 의 subnet 2개와 그 라우팅 설정.
#   - public  subnet : Bastion, NAT Gateway 가 사는 곳 (인터넷 직접 노출 OK)
#   - private subnet : K8s master/worker 가 사는 곳 (인터넷 직접 노출 X)
#
# K8s 가 이 subnet 들을 어떻게 인식?
#   - tags 의 'kubernetes.io/role/elb' 등을 보고
#     "여기는 ALB(외부 노출용) 만들어도 되는 곳" 이라고 인식.
# ─────────────────────────────────────────────────────────────────────────


# public subnet — 인터넷 직접 가능. 외부 ALB 자동 생성에 쓰임.
resource "aws_subnet" "public-ap-northeast-2a" {
  vpc_id            = aws_vpc.kt-cloud-vpc.id
  cidr_block        = var.public_subnet_a_cidr # 기본 10.0.1.0/24 → 256개 IP
  availability_zone = var.az_a
  tags = {
    "kubernetes.io/role/elb" = "1" # AWS LBC 가 외부 ALB 만들 때 이 태그 봄
  }
}

# public subnet 을 public route table 에 연결 → 인터넷 트래픽 = IGW 로
resource "aws_route_table_association" "public-2a-assoc" {
  subnet_id      = aws_subnet.public-ap-northeast-2a.id
  route_table_id = aws_route_table.kt-cloud-public-rt.id
}


# private subnet — 인터넷 직접 X. K8s 노드들이 여기 살음.
resource "aws_subnet" "private-ap-northeast-2a" {
  vpc_id            = aws_vpc.kt-cloud-vpc.id
  cidr_block        = var.private_subnet_a_cidr # 기본 10.0.2.0/24
  availability_zone = var.az_a
  tags = {
    "kubernetes.io/role/internal-elb" = "1" # 내부 ALB(서비스 메시 등) 자동 생성용
  }
}

# private subnet 전용 라우팅 — 인터넷 트래픽은 NAT Gateway 통해서만 나감
resource "aws_route_table" "private-ap-northeast-2a-rt" {
  vpc_id = aws_vpc.kt-cloud-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.ap-northeast-2a-nat-gw.id # ← public 의 IGW 가 아니라 NAT
  }
}

resource "aws_route_table_association" "private-ap-northeast-2a-assoc" {
  subnet_id      = aws_subnet.private-ap-northeast-2a.id
  route_table_id = aws_route_table.private-ap-northeast-2a-rt.id
}
