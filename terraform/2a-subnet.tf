resource "aws_subnet" "public-ap-northeast-2a" {
  vpc_id            = aws_vpc.kt-cloud-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-northeast-2a"
}

resource "aws_route_table_association" "public-2a-assoc" {
  subnet_id      = aws_subnet.public-ap-northeast-2a.id
  route_table_id = aws_route_table.kt-cloud-public-rt.id
}

resource "aws_subnet" "private-ap-northeast-2a" {
  vpc_id            = aws_vpc.kt-cloud-vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-northeast-2a"
}

resource "aws_route_table" "private-ap-northeast-2a-rt" {
  vpc_id = aws_vpc.kt-cloud-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.ap-northeast-2a-nat-gw.id
  }
}

resource "aws_route_table_association" "private-ap-northeast-2a-assoc" {
  subnet_id      = aws_subnet.private-ap-northeast-2a.id
  route_table_id = aws_route_table.private-ap-northeast-2a-rt.id
}
