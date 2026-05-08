# ─────────────────────────────────────────────────────────────────────────
# modules/storage — EFS (공유 파일 시스템) + KMS Customer Managed Key
# ─────────────────────────────────────────────────────────────────────────
# 노드들 간 공유 파일 저장용 EFS + 그 EFS 의 전용 SG.
# (worker 의 EBS 추가 디스크는 compute 모듈에 있음. 그건 인스턴스 전용)
#
# A5 (PDF §5.3): 모든 EBS / EFS / S3 는 KMS Customer Managed Key (CMK) 로
#   SSE 암호화. 여기 만든 KMS 는 EFS 전용. ECR 은 자기 KMS (modules/registry)
#   가 따로 있고, EBS 는 AWS managed key 로 이미 encrypted=true (compute 모듈).
#   향후 S3 (modules/staticpage 같은 D7 작업) 가 추가될 때 이 KMS 또는 별도
#   KMS 를 재사용 가능 — output 으로 노출만 해두면 됨.
# ─────────────────────────────────────────────────────────────────────────


# ─── KMS Customer Managed Key (EFS SSE 암호화용) ─────────────────
# 'Customer Managed Key' = 우리가 IAM 으로 권한 통제 + audit + 키 회전 관리.
# 'AWS Managed Key' (alias/aws/elasticfilesystem) 보다 강한 통제. PDF §5.3 명시.
resource "aws_kms_key" "efs" {
  description             = "${var.name_prefix}-efs encryption (CMK, PDF §5.3)"
  deletion_window_in_days = 7    # 삭제 후 복구 가능 기간 (최소 7일)
  enable_key_rotation     = true # 1년마다 자동 키 회전 (보안 best practice)
}

resource "aws_kms_alias" "efs" {
  name          = "alias/${var.name_prefix}-efs"
  target_key_id = aws_kms_key.efs.key_id
}


# ─── EFS 본체 (KMS 암호화 적용) ───────────────────────────────────
resource "aws_efs_file_system" "this" {
  creation_token = "${var.name_prefix}-cluster-efs"

  # SSE 암호화 활성. kms_key_id 명시 안 하면 AWS managed key 사용.
  # PDF §5.3 의 'CMK' 요구 충족 위해 위에서 만든 우리 키 명시.
  encrypted  = true
  kms_key_id = aws_kms_key.efs.arn
}


# ─── Mount Target ×2 (AZ 마다 1개씩) ──────────────────────────────
# AZ 마다 mount target 이 있어야 그 AZ 의 EC2 가 EFS 를 마운트할 수 있음.
resource "aws_efs_mount_target" "a" {
  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = var.private_subnet_a_id
  security_groups = [aws_security_group.efs.id]
}

resource "aws_efs_mount_target" "b" {
  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = var.private_subnet_b_id
  security_groups = [aws_security_group.efs.id]
}


# ─── EFS 전용 SG (NFS 2049 포트만 허용) ───────────────────────────
resource "aws_security_group" "efs" {
  vpc_id = var.vpc_id

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
}
