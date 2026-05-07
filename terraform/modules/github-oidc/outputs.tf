# GitHub Actions workflow 의 'role-to-assume' 에 적을 ARN.
# (workflow yaml 의 'aws-actions/configure-aws-credentials' step 에 사용)
output "role_arn" {
  description = "GitHub Actions 가 assume 할 IAM Role ARN"
  value       = aws_iam_role.github_actions.arn
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN (다른 모듈/role 에서 재사용 가능)"
  value       = aws_iam_openid_connect_provider.github.arn
}
