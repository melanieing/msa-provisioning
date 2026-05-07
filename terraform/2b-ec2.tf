# ─────────────────────────────────────────────────────────────────────────
# AZ B 의 EC2 들. 2a-ec2.tf 의 거울 짝.
#   - master 1대 (b-master-01)  — Ansible 의 'main-master'. kubeadm init 을 여기서 실행.
#   - worker 2대 (자동 hostname)
#   - bastion 1대
#
# 자세한 옵션 설명은 2a-ec2.tf 헤더 참고.
# ─────────────────────────────────────────────────────────────────────────


# ─── master-01 (AZ B) — kubeadm init 의 주인공 노드 ───────────────
# Ansible main.yaml 에서 'main-master' 그룹 = 이 노드.
# kubeadm 클러스터의 첫 번째 컨트롤플레인. 다른 master 2대는 이 노드의 cert-key 받아서 join.
resource "aws_instance" "ap-northeast-2b-master-node-01" {
  ami                  = var.node_ami_id
  instance_type        = var.master_instance_type
  subnet_id            = aws_subnet.private-ap-northeast-2b.id
  security_groups      = [aws_security_group.cluster-node-sg.id]
  key_name             = aws_key_pair.bastion-node-key.key_name
  iam_instance_profile = aws_iam_instance_profile.ktcloud-cluster-node-profile.name
  source_dest_check    = false

  user_data = <<-EOF
              #!/bin/bash
              hostnamectl set-hostname b-master-01
              EOF
}


# ─── worker-01 (AZ B) ─────────────────────────────────────────────
resource "aws_instance" "ap-northeast-2b-worker-node-01" {
  ami                  = var.node_ami_id
  instance_type        = var.worker_instance_type
  subnet_id            = aws_subnet.private-ap-northeast-2b.id
  security_groups      = [aws_security_group.cluster-node-sg.id]
  key_name             = aws_key_pair.bastion-node-key.key_name
  iam_instance_profile = aws_iam_instance_profile.ktcloud-cluster-node-profile.name
  source_dest_check    = false
}

resource "aws_ebs_volume" "ap-northeast-2b-worker-01-ebs" {
  availability_zone = var.az_b
  size              = var.worker_ebs_size_gb
}

resource "aws_volume_attachment" "ap-northeast-2b-worker-01-ebs-att" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.ap-northeast-2b-worker-01-ebs.id
  instance_id = aws_instance.ap-northeast-2b-worker-node-01.id
}


# ─── worker-02 (AZ B) ─────────────────────────────────────────────
resource "aws_instance" "ap-northeast-2b-worker-node-02" {
  ami                  = var.node_ami_id
  instance_type        = var.worker_instance_type
  subnet_id            = aws_subnet.private-ap-northeast-2b.id
  security_groups      = [aws_security_group.cluster-node-sg.id]
  key_name             = aws_key_pair.bastion-node-key.key_name
  iam_instance_profile = aws_iam_instance_profile.ktcloud-cluster-node-profile.name
  source_dest_check    = false
}

resource "aws_ebs_volume" "ap-northeast-2b-worker-02-ebs" {
  availability_zone = var.az_b
  size              = var.worker_ebs_size_gb
}

resource "aws_volume_attachment" "ap-northeast-2b-worker-02-ebs-att" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.ap-northeast-2b-worker-02-ebs.id
  instance_id = aws_instance.ap-northeast-2b-worker-node-02.id
}


# ─── bastion (AZ B) ───────────────────────────────────────────────
resource "aws_instance" "ap-northeast-2b-bastion-node" {
  ami                         = var.node_ami_id
  instance_type               = var.bastion_instance_type
  subnet_id                   = aws_subnet.public-ap-northeast-2b.id
  security_groups             = [aws_security_group.bastion-node-sg.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.bastion-node-key.key_name
}
