resource "aws_eip" "ap-northeast-2a-nat-eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "ap-northeast-2a-nat-gw" {
  allocation_id = aws_eip.ap-northeast-2a-nat-eip.id
  subnet_id     = aws_subnet.public-ap-northeast-2a.id
  depends_on    = [aws_internet_gateway.main_igw]
}
