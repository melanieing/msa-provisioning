resource "aws_efs_file_system" "kt-cloud-cluster-efs" {
  creation_token = "kt-cloud-cluster-efs"
}

resource "aws_efs_mount_target" "private-ap-northeast-2a-mt" {
  file_system_id  = aws_efs_file_system.kt-cloud-cluster-efs.id
  subnet_id       = aws_subnet.private-ap-northeast-2a.id
  security_groups = [aws_security_group.kt-cloud-cluster-efs-sg.id]
}

resource "aws_efs_mount_target" "private-ap-northeast-2b-mt" {
  file_system_id  = aws_efs_file_system.kt-cloud-cluster-efs.id
  subnet_id       = aws_subnet.private-ap-northeast-2b.id
  security_groups = [aws_security_group.kt-cloud-cluster-efs-sg.id]
}

resource "aws_security_group" "kt-cloud-cluster-efs-sg" {
  vpc_id = aws_vpc.kt-cloud-vpc.id

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.kt-cloud-vpc.cidr_block]
  }
}
