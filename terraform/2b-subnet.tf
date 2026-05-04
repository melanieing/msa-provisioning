resource "aws_subnet" "public-ap-northeast-2b" {
  vpc_id            = aws_vpc.kt-cloud-vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ap-northeast-2b"
}

resource "aws_route_table_association" "public-2b-assoc" {
  subnet_id      = aws_subnet.public-ap-northeast-2b.id
  route_table_id = aws_route_table.kt-cloud-public-rt.id
}

resource "aws_subnet" "private-ap-northeast-2b" {
  vpc_id            = aws_vpc.kt-cloud-vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "ap-northeast-2b"
}

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
