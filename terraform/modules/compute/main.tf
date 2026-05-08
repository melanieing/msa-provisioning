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
# pathexpand() 가 '~/.ssh/...' 같은 표현을 host OS 의 home 경로로 확장.
# Windows 에선 'C:/Users/<user>/.ssh/...', Linux/WSL 에선 '/home/<user>/.ssh/...'.
# 사용자가 어떤 환경에서 terraform 돌리든 default('~/...') 가 그대로 작동.
resource "aws_key_pair" "this" {
  key_name   = var.ssh_key_name
  public_key = file(pathexpand(var.ssh_public_key_path))
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
# ⚠️ K8s 1.27+ 부터 kubelet 의 in-tree ECR 인증이 제거되어, 이 정책만으로는 부족.
# `ecr-credential-provider` 외부 플러그인이 노드별 설치돼야 함 (ansible/ecr-credential-provider-setup.yaml).
resource "aws_iam_role_policy_attachment" "node_ecr_readonly" {
  role       = data.aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}


# ─── EBS CSI Driver 권한을 노드 Role 에 부착 ──────────────────────
# Self-managed K8s 1.27+ 부터 in-tree EBS volume plugin 도 제거.
# PVC 가 EBS 볼륨에 binding 하려면 EBS CSI driver 가 별도 설치돼야 하고,
# 그 driver 가 ec2:CreateVolume / AttachVolume / DetachVolume 호출하므로
# 노드 Role 에 아래 AWS 관리형 정책 부착.
# (driver 자체 install 은 ansible/ebs-csi-setup.yaml)
resource "aws_iam_role_policy_attachment" "node_ebs_csi" {
  role       = data.aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}


# ═════════════════════════════════════════════════════════════════
# AZ A — master ×2 + worker ×1 + bastion ×1
# ═════════════════════════════════════════════════════════════════

# ─── master-01 (AZ A) ─────────────────────────────────────────────
resource "aws_instance" "ap-northeast-2a-master-node-01" {
  ami                    = var.node_ami_id
  instance_type          = var.master_instance_type
  subnet_id              = var.private_subnet_a_id
  vpc_security_group_ids = [var.cluster_node_sg_id]
  key_name               = aws_key_pair.this.key_name
  iam_instance_profile   = aws_iam_instance_profile.node.name
  source_dest_check      = false # CNI Pod 통신용

  user_data = <<-EOF
              #!/bin/bash
              hostnamectl set-hostname a-master-01
              EOF

  # K8s 노드 root 볼륨. 기본 8GB 는 image 캐시 (containerd) 가 빠르게 채워서 DiskPressure 발생.
  # 2026-05-10 발견 (이슈 H): worker 노드들이 8GB 에서 며칠 운영 시 가득 참. 30GB 로 상향.
  root_block_device {
    volume_size = var.node_root_volume_size_gb
    volume_type = "gp3"
    encrypted   = true # 보안 (PDF 5.3절 KMS SSE 와 시너지)
  }

  # 옛 'security_groups' 속성과 'vpc_security_group_ids' 사이에 perpetual drift 방지.
  lifecycle {
    ignore_changes = [security_groups]
  }
}

# ─── master-02 (AZ A) ─────────────────────────────────────────────
resource "aws_instance" "ap-northeast-2a-master-node-02" {
  ami                    = var.node_ami_id
  instance_type          = var.master_instance_type
  subnet_id              = var.private_subnet_a_id
  vpc_security_group_ids = [var.cluster_node_sg_id]
  key_name               = aws_key_pair.this.key_name
  iam_instance_profile   = aws_iam_instance_profile.node.name
  source_dest_check      = false

  user_data = <<-EOF
              #!/bin/bash
              hostnamectl set-hostname a-master-02
              EOF

  root_block_device {
    volume_size = var.node_root_volume_size_gb
    volume_type = "gp3"
    encrypted   = true
  }

  lifecycle {
    ignore_changes = [security_groups]
  }
}

# ─── worker-01 (AZ A) + EBS ───────────────────────────────────────
resource "aws_instance" "ap-northeast-2a-worker-node-01" {
  ami                    = var.node_ami_id
  instance_type          = var.worker_instance_type
  subnet_id              = var.private_subnet_a_id
  vpc_security_group_ids = [var.cluster_node_sg_id]
  key_name               = aws_key_pair.this.key_name
  iam_instance_profile   = aws_iam_instance_profile.node.name
  source_dest_check      = false

  root_block_device {
    volume_size = var.node_root_volume_size_gb
    volume_type = "gp3"
    encrypted   = true
  }

  lifecycle {
    ignore_changes = [security_groups]
  }
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
  vpc_security_group_ids      = [var.bastion_sg_id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.this.key_name

  lifecycle {
    ignore_changes = [security_groups]
  }
}


# ═════════════════════════════════════════════════════════════════
# AZ B — master ×1 + worker ×2 + bastion ×1
# ═════════════════════════════════════════════════════════════════

# ─── master-01 (AZ B) — kubeadm init 의 main-master ───────────────
# Ansible 의 'main-master' 그룹 = 이 노드. kubeadm init 을 여기서 실행.
resource "aws_instance" "ap-northeast-2b-master-node-01" {
  ami                    = var.node_ami_id
  instance_type          = var.master_instance_type
  subnet_id              = var.private_subnet_b_id
  vpc_security_group_ids = [var.cluster_node_sg_id]
  key_name               = aws_key_pair.this.key_name
  iam_instance_profile   = aws_iam_instance_profile.node.name
  source_dest_check      = false

  user_data = <<-EOF
              #!/bin/bash
              hostnamectl set-hostname b-master-01
              EOF

  root_block_device {
    volume_size = var.node_root_volume_size_gb
    volume_type = "gp3"
    encrypted   = true
  }

  lifecycle {
    ignore_changes = [security_groups]
  }
}

# ─── worker-01 (AZ B) + EBS ───────────────────────────────────────
resource "aws_instance" "ap-northeast-2b-worker-node-01" {
  ami                    = var.node_ami_id
  instance_type          = var.worker_instance_type
  subnet_id              = var.private_subnet_b_id
  vpc_security_group_ids = [var.cluster_node_sg_id]
  key_name               = aws_key_pair.this.key_name
  iam_instance_profile   = aws_iam_instance_profile.node.name
  source_dest_check      = false

  root_block_device {
    volume_size = var.node_root_volume_size_gb
    volume_type = "gp3"
    encrypted   = true
  }

  lifecycle {
    ignore_changes = [security_groups]
  }
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
  ami                    = var.node_ami_id
  instance_type          = var.worker_instance_type
  subnet_id              = var.private_subnet_b_id
  vpc_security_group_ids = [var.cluster_node_sg_id]
  key_name               = aws_key_pair.this.key_name
  iam_instance_profile   = aws_iam_instance_profile.node.name
  source_dest_check      = false

  root_block_device {
    volume_size = var.node_root_volume_size_gb
    volume_type = "gp3"
    encrypted   = true
  }

  lifecycle {
    ignore_changes = [security_groups]
  }
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
  vpc_security_group_ids      = [var.bastion_sg_id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.this.key_name

  lifecycle {
    ignore_changes = [security_groups]
  }
}
