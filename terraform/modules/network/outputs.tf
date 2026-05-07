# network 모듈 출력 — 다른 모듈(security, compute, lb, storage)이 참조

output "vpc_id" {
  description = "이 모듈이 만든 VPC 의 ID"
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "VPC 의 CIDR (security/storage 모듈의 SG ingress 에 사용)"
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_a_id" {
  value = aws_subnet.public_a.id
}

output "public_subnet_b_id" {
  value = aws_subnet.public_b.id
}

output "private_subnet_a_id" {
  value = aws_subnet.private_a.id
}

output "private_subnet_b_id" {
  value = aws_subnet.private_b.id
}
