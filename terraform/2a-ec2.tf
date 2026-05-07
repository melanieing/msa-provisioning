# ─────────────────────────────────────────────────────────────────────────
# AZ A 에 띄울 EC2 들:
#   - master 2대 (a-master-01, a-master-02) — K8s 컨트롤플레인
#   - worker 1대 (a-worker-01)              — 실제 Pod 가 도는 노드
#   - bastion 1대                            — 외부에서 SSH 들어오는 입구
#
# AZ B 에는 master 1대 + worker 2대 + bastion 1대가 있어 (2b-ec2.tf 참고).
# 합치면 master 3 + worker 3 (HA 구성) + bastion 2.
#
# 모든 master/worker 공통:
#   - private subnet 에 위치 (외부 노출 X)
#   - cluster-node-sg 방화벽 규칙 적용
#   - 같은 SSH 키로 접속
#   - IAM Instance Profile 부착 → AWS 콘솔 권한 받음 (LBC 가 ALB 만들 때 필요)
#   - source_dest_check = false : K8s 의 Pod 간 통신은 노드 IP가 아닌 Pod IP를 패킷에 담아
#     보내는데, AWS 가 기본적으로 "패킷의 src/dst 가 노드 IP 가 아니면 차단" 함.
#     그걸 끄는 옵션. CNI 가 Pod 트래픽을 정상 처리하려면 필수.
# ─────────────────────────────────────────────────────────────────────────


# ─── master-01 (AZ A) ─────────────────────────────────────────────
resource "aws_instance" "ap-northeast-2a-master-node-01" {
  ami                  = var.node_ami_id          # AMI = OS 이미지 (기본 Amazon Linux 2)
  instance_type        = var.master_instance_type # 기본 t3.medium
  subnet_id            = aws_subnet.private-ap-northeast-2a.id
  security_groups      = [aws_security_group.cluster-node-sg.id]
  key_name             = aws_key_pair.bastion-node-key.key_name
  iam_instance_profile = aws_iam_instance_profile.ktcloud-cluster-node-profile.name
  source_dest_check    = false # CNI Pod 통신용 (위 설명 참고)

  # 부팅 직후 한 번 실행되는 스크립트. hostname 설정에만 씀.
  # Ansible 이 이 hostname 을 보고 'a-master-01' 같은 식으로 노드 식별.
  user_data = <<-EOF
              #!/bin/bash
              hostnamectl set-hostname a-master-01
              EOF
}


# ─── master-02 (AZ A) — master-01 과 같은 구성 ─────────────────────
resource "aws_instance" "ap-northeast-2a-master-node-02" {
  ami                  = var.node_ami_id
  instance_type        = var.master_instance_type
  subnet_id            = aws_subnet.private-ap-northeast-2a.id
  security_groups      = [aws_security_group.cluster-node-sg.id]
  key_name             = aws_key_pair.bastion-node-key.key_name
  iam_instance_profile = aws_iam_instance_profile.ktcloud-cluster-node-profile.name
  source_dest_check    = false

  user_data = <<-EOF
              #!/bin/bash
              hostnamectl set-hostname a-master-02
              EOF
}


# ─── worker-01 (AZ A) — hostname 자동, EBS 추가 부착 ──────────────
resource "aws_instance" "ap-northeast-2a-worker-node-01" {
  ami                  = var.node_ami_id
  instance_type        = var.worker_instance_type # 기본 t3.medium
  subnet_id            = aws_subnet.private-ap-northeast-2a.id
  security_groups      = [aws_security_group.cluster-node-sg.id]
  key_name             = aws_key_pair.bastion-node-key.key_name
  iam_instance_profile = aws_iam_instance_profile.ktcloud-cluster-node-profile.name
  source_dest_check    = false
  # worker 는 hostname 자동 (10.0.2.x → ip-10-0-2-X 같은 기본 이름)
}

# 워커에 추가 EBS 디스크 (Pod 의 PVC 로 쓰임)
resource "aws_ebs_volume" "ap-northeast-2a-worker-01-ebs" {
  availability_zone = var.az_a
  size              = var.worker_ebs_size_gb
}

# 위 EBS 를 worker 에 마운트. /dev/sdh 는 Linux 가 보는 디스크 디바이스 이름.
resource "aws_volume_attachment" "ap-northeast-2a-worker-01-ebs-att" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.ap-northeast-2a-worker-01-ebs.id
  instance_id = aws_instance.ap-northeast-2a-worker-node-01.id
}


# ─── bastion (AZ A) — public subnet, 공인 IP 부여 ────────────────
# Bastion = "외부에서 클러스터 들어가려면 반드시 거쳐야 하는 점프 호스트".
# 이 서버에 SSH 로 들어가서, 거기서 다시 master/worker 로 SSH (ProxyJump).
resource "aws_instance" "ap-northeast-2a-bastion-node" {
  ami                         = var.node_ami_id
  instance_type               = var.bastion_instance_type            # 작은 거(t3.nano) 면 충분
  subnet_id                   = aws_subnet.public-ap-northeast-2a.id # public 에 둠
  security_groups             = [aws_security_group.bastion-node-sg.id]
  associate_public_ip_address = true # 외부 접근용 공인 IP
  key_name                    = aws_key_pair.bastion-node-key.key_name
}
