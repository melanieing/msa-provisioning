# network 모듈 입력 변수 — 루트 variables.tf 의 같은 이름 변수에서 받아옴

variable "vpc_cidr" {
  description = "VPC 전체 IP 대역"
  type        = string
}

variable "az_a" {
  description = "첫 번째 가용영역 이름"
  type        = string
}

variable "az_b" {
  description = "두 번째 가용영역 이름"
  type        = string
}

variable "public_subnet_a_cidr" {
  description = "AZ A 의 public subnet IP 대역"
  type        = string
}

variable "private_subnet_a_cidr" {
  description = "AZ A 의 private subnet IP 대역"
  type        = string
}

variable "public_subnet_b_cidr" {
  description = "AZ B 의 public subnet IP 대역"
  type        = string
}

variable "private_subnet_b_cidr" {
  description = "AZ B 의 private subnet IP 대역"
  type        = string
}
