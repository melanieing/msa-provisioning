# ─────────────────────────────────────────────────────────────────────────
# modules/storage — EFS (공유 파일 시스템)
# ─────────────────────────────────────────────────────────────────────────
# 노드들 간 공유 파일 저장용 EFS + 그 EFS 의 전용 SG.
# (worker 의 EBS 추가 디스크는 compute 모듈에 있음. 그건 인스턴스 전용)
# ─────────────────────────────────────────────────────────────────────────


# ─── EFS 본체 ─────────────────────────────────────────────────────
resource "aws_efs_file_system" "this" {
  creation_token = "${var.name_prefix}-cluster-efs"
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
