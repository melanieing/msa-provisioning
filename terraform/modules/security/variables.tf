# security 모듈 입력 — network 모듈에서 받아옴

variable "vpc_id" {
  description = "SG 가 살 VPC 의 ID"
  type        = string
}

variable "vpc_cidr" {
  description = "ingress 규칙의 source CIDR (= VPC 전체 대역)"
  type        = string
}
