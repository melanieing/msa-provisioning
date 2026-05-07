# storage 모듈 출력

output "efs_id" {
  description = "EFS 파일시스템 ID (필요 시 Pod PVC 등에서 참조)"
  value       = aws_efs_file_system.this.id
}
