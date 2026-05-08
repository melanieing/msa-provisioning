# storage 모듈 출력

output "efs_id" {
  description = "EFS 파일시스템 ID (필요 시 Pod PVC 등에서 참조)"
  value       = aws_efs_file_system.this.id
}

# A5 후속: 향후 S3 등에서 같은 CMK 재사용 위해 노출.
output "kms_key_arn" {
  description = "EFS 용 KMS CMK ARN (S3 등 다른 storage 가 재사용 가능)"
  value       = aws_kms_key.efs.arn
}
