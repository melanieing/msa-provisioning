# ─────────────────────────────────────────────────────────────────────────
# modules/compute — EC2 8대 + EBS + Key Pair + IAM Instance Profile
# ─────────────────────────────────────────────────────────────────────────
# 클러스터의 컴퓨팅 자원 전부:
#   - SSH Key Pair (모든 EC2 공통)
#   - IAM Instance Profile (기존 Role 을 EC2 에 부착하기 위한 어댑터)
#   - master ×3 (HA 구성)
#   - worker ×3 (각자 EBS 추가 디스크)
#   - bastion ×2 (AZ 별 1개씩)
# ─────────────────────────────────────────────────────────────────────────


# ─── SSH Key Pair (모든 EC2 공통) ──────────────────────────────────
resource "aws_key_pair" "this" {
  key_name   = var.ssh_key_name
  public_key = file(var.ssh_public_key_path)
}


# ─── IAM Instance Profile ──────────────────────────────────────────
# Role 자체는 콘솔에서 미리 만들어둔 거 (이 Terraform 으로 안 만듦).
# data 블록으로 읽어와서 Instance Profile 로 감싸서 EC2 에 부착 가능하게 만듦.
data "aws_iam_role" "node" {
  name = var.node_iam_role_name
}

resource "aws_iam_instance_profile" "node" {
  name = var.node_iam_instance_profile_name
  role = data.aws_iam_role.node.name
}


# ─── ECR Pull 권한을 노드 Role 에 부착 ────────────────────────────
# K8s 가 ECR private repo 에서 이미지를 pull 하려면 노드에 권한 필요.
# AWS 관리형 정책 'AmazonEC2ContainerRegistryReadOnly' 사용 — pull only, push X.
# (이 권한이 있으면 K8s manifest 에 imagePullSecret 안 만들어도 됨)
resource "aws_iam_role_policy_attachment" "node_ecr_readonly" {
  role       = data.aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}


# ═════════════════════════════════════════════════════════════════
# AZ A — master ×2 + worker ×1 + bastion ×1
# ═════════════════════════════════════════════════════════════════

# ─── master-01 (AZ A) ─────────────────────────────────────────────
resource "aws_instance" "ap-northeast-2a-master-node-01" {
  ami                  = var.node_ami_id
  instance_type        = var.master_instance_type
  subnet_id            = var.private_subnet_a_id
  security_groups      = [var.cluster_node_sg_id]
  key_name             = aws_key_pair.this.key_name
  iam_instance_profile = aws_iam_instance_profile.node.name
  source_dest_check    = false # CNI Pod 통신용

  user_data = <<-EOF
              #!/bin/bash
              hostnamectl set-hostname a-master-01
              EOF
}

# ─── master-02 (AZ A) ─────────────────────────────────────────────
resource "aws_instance" "ap-northeast-2a-master-node-02" {
  ami                  = var.node_ami_id
  instance_type        = var.master_instance_type
  subnet_id            = var.private_subnet_a_id
  security_groups      = [var.cluster_node_sg_id]
  key_name             = aws_key_pair.this.key_name
  iam_instance_profile = aws_iam_instance_profile.node.name
  source_dest_check    = false

  user_data = <<-EOF
              #!/bin/bash
              hostnamectl set-hostname a-master-02
              EOF
}

# ─── worker-01 (AZ A) + EBS ───────────────────────────────────────
resource "aws_instance" "ap-northeast-2a-worker-node-01" {
  ami                  = var.node_ami_id
  instance_type        = var.worker_instance_type
  subnet_id            = var.private_subnet_a_id
  security_groups      = [var.cluster_node_sg_id]
  key_name             = aws_key_pair.this.key_name
  iam_instance_profile = aws_iam_instance_profile.node.name
  source_dest_check    = false
}

resource "aws_ebs_volume" "ap-northeast-2a-worker-01-ebs" {
  availability_zone = var.az_a
  size              = var.worker_ebs_size_gb
}

resource "aws_volume_attachment" "ap-northeast-2a-worker-01-ebs-att" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.ap-northeast-2a-worker-01-ebs.id
  instance_id = aws_instance.ap-northeast-2a-worker-node-01.id
}

# ─── bastion (AZ A) ───────────────────────────────────────────────
resource "aws_instance" "ap-northeast-2a-bastion-node" {
  ami                         = var.node_ami_id
  instance_type               = var.bastion_instance_type
  subnet_id                   = var.public_subnet_a_id
  security_groups             = [var.bastion_sg_id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.this.key_name
}


# ═════════════════════════════════════════════════════════════════
# AZ B — master ×1 + worker ×2 + bastion ×1
# ═════════════════════════════════════════════════════════════════

# ─── master-01 (AZ B) — kubeadm init 의 main-master ───────────────
# Ansible 의 'main-master' 그룹 = 이 노드. kubeadm init 을 여기서 실행.
resource "aws_instance" "ap-northeast-2b-master-node-01" {
  ami                  = var.node_ami_id
  instance_type        = var.master_instance_type
  subnet_id            = var.private_subnet_b_id
  security_groups      = [var.cluster_node_sg_id]
  key_name             = aws_key_pair.this.key_name
  iam_instance_profile = aws_iam_instance_profile.node.name
  source_dest_check    = false

  user_data = <<-EOF
              #!/bin/bash
              hostnamectl set-hostname b-master-01
              EOF
}

# ─── worker-01 (AZ B) + EBS ───────────────────────────────────────
resource "aws_instance" "ap-northeast-2b-worker-node-01" {
  ami                  = var.node_ami_id
  instance_type        = var.worker_instance_type
  subnet_id            = var.private_subnet_b_id
  security_groups      = [var.cluster_node_sg_id]
  key_name             = aws_key_pair.this.key_name
  iam_instance_profile = aws_iam_instance_profile.node.name
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

# ─── worker-02 (AZ B) + EBS ───────────────────────────────────────
resource "aws_instance" "ap-northeast-2b-worker-node-02" {
  ami                  = var.node_ami_id
  instance_type        = var.worker_instance_type
  subnet_id            = var.private_subnet_b_id
  security_groups      = [var.cluster_node_sg_id]
  key_name             = aws_key_pair.this.key_name
  iam_instance_profile = aws_iam_instance_profile.node.name
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
  subnet_id                   = var.public_subnet_b_id
  security_groups             = [var.bastion_sg_id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.this.key_name
}
