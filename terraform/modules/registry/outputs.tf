# ECR repository URL — GitHub Actions workflow + Helm values 에서 사용
# 형식: <account_id>.dkr.ecr.<region>.amazonaws.com/<repo_name>
output "repository_urls" {
  description = "service name -> ECR repo URL"
  value       = { for name, repo in aws_ecr_repository.this : name => repo.repository_url }
}

# ECR repository ARN — github-oidc 모듈의 IAM 정책에서 push 권한 제한에 사용
output "repository_arns" {
  description = "service name -> ECR repo ARN"
  value       = { for name, repo in aws_ecr_repository.this : name => repo.arn }
}

output "kms_key_arn" {
  description = "ECR 암호화에 사용하는 KMS 키 ARN"
  value       = aws_kms_key.ecr.arn
}
