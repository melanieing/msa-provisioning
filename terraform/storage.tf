# ─────────────────────────────────────────────────────────────────────────
# 클러스터가 쓸 EFS (네트워크 파일 시스템) 와 EFS 전용 보안그룹.
#
# EFS vs EBS 차이?
#   - EBS = "USB 드라이브" 같은 거. EC2 1대에만 붙음. 한 AZ 안에서만 사용.
#   - EFS = "공유 폴더" 같은 거. 여러 EC2 가 동시에 마운트 가능. 여러 AZ 에서 접근 가능.
#
# 우리 클러스터는 왜 EFS 가 필요?
#   - 여러 노드가 공유해야 하는 설정/로그를 둘 데 (PDF 5.3절: "공유 설정 · 로그").
#   - EBS PVC (=각 Pod 전용 디스크) 와는 용도가 다름.
# ─────────────────────────────────────────────────────────────────────────


# EFS 본체 — AZ 와 무관한 region 단위 자원.
resource "aws_efs_file_system" "kt-cloud-cluster-efs" {
  # creation_token = "이 EFS 의 고유 식별자". 이미 같은 token 의 EFS 가 있으면 새로 안 만들고 재사용.
  creation_token = "${var.name_prefix}-cluster-efs"
}


# Mount Target = "이 AZ 의 EC2 가 EFS 에 접속할 수 있도록 만드는 진입 포트".
# AZ 마다 1개씩 만들어야 그 AZ 의 EC2 가 마운트 가능.

# AZ A 용 mount target
resource "aws_efs_mount_target" "private-ap-northeast-2a-mt" {
  file_system_id  = aws_efs_file_system.kt-cloud-cluster-efs.id
  subnet_id       = aws_subnet.private-ap-northeast-2a.id # private subnet 에 둠
  security_groups = [aws_security_group.kt-cloud-cluster-efs-sg.id]
}

# AZ B 용 mount target
resource "aws_efs_mount_target" "private-ap-northeast-2b-mt" {
  file_system_id  = aws_efs_file_system.kt-cloud-cluster-efs.id
  subnet_id       = aws_subnet.private-ap-northeast-2b.id
  security_groups = [aws_security_group.kt-cloud-cluster-efs-sg.id]
}


# EFS 전용 방화벽 — VPC 안에서 NFS(2049) 포트 허용
resource "aws_security_group" "kt-cloud-cluster-efs-sg" {
  vpc_id = aws_vpc.kt-cloud-vpc.id

  ingress {
    from_port   = 2049 # NFS 표준 포트
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.kt-cloud-vpc.cidr_block] # VPC 내부에서만 접근 허용
  }
}
