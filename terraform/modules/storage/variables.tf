# storage 모듈 입력

variable "name_prefix" {
  description = "EFS creation_token 에 붙는 prefix"
  type        = string
}

variable "vpc_id" {
  description = "EFS SG 가 살 VPC 의 ID"
  type        = string
}

variable "vpc_cidr" {
  description = "EFS NFS 포트 허용 source CIDR (= VPC 전체)"
  type        = string
}

variable "private_subnet_a_id" {
  description = "AZ A 의 private subnet (mount target 위치)"
  type        = string
}

variable "private_subnet_b_id" {
  description = "AZ B 의 private subnet"
  type        = string
}
