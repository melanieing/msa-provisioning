# ─────────────────────────────────────────────────────────────────────────
# NAT Gateway = "private subnet 안의 노드들이 인터넷에 나갈 때 쓰는 출구".
#   - private 노드는 외부에서 직접 안 보이지만, 외부로는 나갈 수 있어야 함
#     (yum install, kubectl pull 등을 위해).
#   - NAT 가 그 출구 역할.
#
# 비용 메모: NAT Gateway 는 시간당 ~60원 + 데이터 처리량당 추가 과금.
# 비용 줄이려면 NAT 1개만 둬서 두 AZ 공용으로 쓰는 방법도 있음 (HA 손해 vs 비용 절감 트레이드).
# ─────────────────────────────────────────────────────────────────────────

# NAT 도 외부에서 보이는 IP 가 필요해서 EIP 할당.
resource "aws_eip" "ap-northeast-2a-nat-eip" {
  domain = "vpc"
}

# NAT Gateway. public subnet 에 둬야 함 (외부 통신을 위해).
resource "aws_nat_gateway" "ap-northeast-2a-nat-gw" {
  allocation_id = aws_eip.ap-northeast-2a-nat-eip.id
  subnet_id     = aws_subnet.public-ap-northeast-2a.id
  depends_on    = [aws_internet_gateway.main_igw] # IGW 가 먼저 만들어진 후 NAT 생성
}
