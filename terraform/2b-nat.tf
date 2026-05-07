# ─────────────────────────────────────────────────────────────────────────
# 이 파일은 뭐 하는 파일?
# ─────────────────────────────────────────────────────────────────────────
# AZ B 의 NAT Gateway. 2a-nat.tf 의 거울 짝.
# 두 AZ 에 각각 NAT 를 두면 한 AZ 다운 시에도 다른 AZ 의 노드는 인터넷 가능.
# ─────────────────────────────────────────────────────────────────────────

resource "aws_eip" "ap-northeast-2b-nat-eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "ap-northeast-2b-nat-gw" {
  allocation_id = aws_eip.ap-northeast-2b-nat-eip.id
  subnet_id     = aws_subnet.public-ap-northeast-2b.id
  depends_on    = [aws_internet_gateway.main_igw]
}
