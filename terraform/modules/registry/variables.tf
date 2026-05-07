variable "name_prefix" {
  description = "리소스 이름 prefix (KMS alias 등에 사용). 예: 'kt-cloud'"
  type        = string
}

variable "repository_names" {
  description = "만들 ECR repository 이름 목록 (서비스 1개당 1개)"
  type        = list(string)
}
