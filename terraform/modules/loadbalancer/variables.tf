# loadbalancer 모듈 입력

variable "name_prefix" {
  description = "NLB 이름에 붙을 prefix (예: 'kt-cloud' → 'kt-cloud-nlb')"
  type        = string
}

variable "vpc_id" {
  description = "Target Group 이 살 VPC 의 ID"
  type        = string
}

variable "public_subnet_a_id" {
  description = "AZ A 의 public subnet (NLB 노출용)"
  type        = string
}

variable "public_subnet_b_id" {
  description = "AZ B 의 public subnet"
  type        = string
}

variable "master_instance_ids" {
  description = "Target Group 에 등록할 master EC2 ID 들 (길이 3)"
  type        = list(string)
}
