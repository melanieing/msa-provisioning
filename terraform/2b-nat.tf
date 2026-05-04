resource "aws_eip" "ap-northeast-2b-nat-eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "ap-northeast-2b-nat-gw" {
  allocation_id = aws_eip.ap-northeast-2b-nat-eip.id
  subnet_id     = aws_subnet.public-ap-northeast-2b.id
  depends_on    = [aws_internet_gateway.main_igw]
}
