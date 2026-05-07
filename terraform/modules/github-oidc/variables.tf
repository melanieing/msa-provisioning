variable "name_prefix" {
  description = "리소스 이름 prefix (예: 'kt-cloud' → 'kt-cloud-github-actions-role')"
  type        = string
}

variable "github_owner" {
  description = "GitHub organization 또는 user 이름. 예: 'melanieing'"
  type        = string
}

variable "github_repo" {
  description = "이 role 을 사용할 GitHub repository 이름. 예: 'msa-spring-boot'"
  type        = string
}

variable "ecr_repository_arns" {
  description = "이 role 이 push 할 수 있는 ECR repository ARN 목록"
  type        = list(string)
}
