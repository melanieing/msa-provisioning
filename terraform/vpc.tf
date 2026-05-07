# ─────────────────────────────────────────────────────────────────────────
# 클러스터 네트워크의 뼈대를 만드는 파일.
#   1) VPC (사설 네트워크)
#   2) Internet Gateway (외부 인터넷으로 나가는 통로)
#   3) NLB + Target Group (K8s API 서버 6443 을 외부에 노출)
#   4) Public Route Table (public subnet 의 트래픽 경로)
#   5) Security Group (방화벽 규칙) — 클러스터 노드용 / Bastion 용
# ─────────────────────────────────────────────────────────────────────────


# ─── 1. VPC (전체 사설 네트워크 박스) ──────────────────────────────
resource "aws_vpc" "kt-cloud-vpc" {
  cidr_block           = var.vpc_cidr # 기본 10.0.0.0/16 → 6만5천개 IP
  enable_dns_hostnames = true         # EC2 가 자동으로 DNS 이름 받게 함
}


# ─── 2. Internet Gateway (VPC 와 인터넷 연결 통로) ─────────────────
# IGW: VPC 1개당 1개. public subnet 의 트래픽이 인터넷으로 나가는 출입구.
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.kt-cloud-vpc.id
}


# ─── 3. NLB 용 EIP (탄력적 IP, 고정 공인 IP) ──────────────────────
# AZ 마다 1개씩 NLB 에 붙임 → NLB 의 외부 IP 가 영구 고정됨.
# 비용 메모: EIP 가 어떤 리소스에 붙어있으면 무료, 안 붙어있으면 시간당 ~7원 과금됨.
resource "aws_eip" "nlb_eip_2a" {
  domain = "vpc" # VPC 안에서 쓰는 EIP (= 옛 'vpc=true')
}

resource "aws_eip" "nlb_eip_2b" {
  domain = "vpc"
}


# ─── 4. NLB (Network Load Balancer) ────────────────────────────────
# K8s API 서버(6443)를 외부에 노출하기 위한 L4 로드밸런서.
# 왜 L4 (TCP) 인가? K8s API 통신은 mTLS (TCP 위에 TLS) 인데, ALB 는 TLS 종료가 들어가서 호환 안 됨.
# 그래서 그냥 TCP 패킷 라우팅만 하는 NLB 사용.
resource "aws_lb" "kt-cloud-nlb" {
  name               = "${var.name_prefix}-nlb" # 예: 'kt-cloud-nlb'
  internal           = false                    # 외부 인터넷에서 접근 가능 (= public)
  load_balancer_type = "network"                # NLB

  # 어떤 subnet 에 어떤 EIP 로 노출할지 (AZ 별 1개씩 = 2개)
  subnet_mapping {
    subnet_id     = aws_subnet.public-ap-northeast-2a.id
    allocation_id = aws_eip.nlb_eip_2a.id
  }
  subnet_mapping {
    subnet_id     = aws_subnet.public-ap-northeast-2b.id
    allocation_id = aws_eip.nlb_eip_2b.id
  }
}


# ─── 5. Target Group (NLB 가 어디로 트래픽 보낼지 등록부) ─────────
# K8s API 의 표준 포트 6443. master 3대를 여기에 등록 (아래 attachment 들).
resource "aws_lb_target_group" "k8s-api-tg" {
  name     = "k8s-api-tg" # 짧은 이름. 길면 AWS 가 거부.
  port     = 6443
  protocol = "TCP"
  vpc_id   = aws_vpc.kt-cloud-vpc.id

  # 헬스체크: 10초마다 6443 포트 TCP 연결 시도 → 응답 없으면 그 노드 제외.
  health_check {
    protocol = "TCP"
    port     = "6443"
    interval = 10
  }
}


# ─── 6. NLB Listener (들어온 트래픽을 어디로 forward 할지) ────────
resource "aws_lb_listener" "k8s-api-listener" {
  load_balancer_arn = aws_lb.kt-cloud-nlb.arn
  port              = 6443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.k8s-api-tg.arn
  }
}


# ─── 7. master 3대를 Target Group 에 등록 ─────────────────────────
# kubeadm join 시 'NLB 주소:6443' 으로 접속 → NLB 가 살아있는 master 중 하나로 연결.
resource "aws_lb_target_group_attachment" "ap-northeast-2a-master-node-01-attach" {
  target_group_arn = aws_lb_target_group.k8s-api-tg.arn
  target_id        = aws_instance.ap-northeast-2a-master-node-01.id
  port             = 6443
}

resource "aws_lb_target_group_attachment" "ap-northeast-2a-master-node-02-attach" {
  target_group_arn = aws_lb_target_group.k8s-api-tg.arn
  target_id        = aws_instance.ap-northeast-2a-master-node-02.id
  port             = 6443
}

resource "aws_lb_target_group_attachment" "ap-northeast-2b-master-node-01-attach" {
  target_group_arn = aws_lb_target_group.k8s-api-tg.arn
  target_id        = aws_instance.ap-northeast-2b-master-node-01.id
  port             = 6443
}


# ─── 8. Public Route Table (public subnet 의 트래픽 경로) ─────────
# public subnet 에서 0.0.0.0/0 (모든 인터넷) 으로 가는 트래픽은 IGW 로 보내라는 규칙.
resource "aws_route_table" "kt-cloud-public-rt" {
  vpc_id = aws_vpc.kt-cloud-vpc.id

  route {
    cidr_block = "0.0.0.0/0" # 모든 IP 대역
    gateway_id = aws_internet_gateway.main_igw.id
  }
}


# ─── 9. cluster-node-sg : K8s 노드용 방화벽 ───────────────────────
# Security Group(SG) = AWS 의 방화벽. inbound(들어오는) 와 outbound(나가는) 규칙으로 구성.
resource "aws_security_group" "cluster-node-sg" {
  name   = "cluster-node-sg"
  vpc_id = aws_vpc.kt-cloud-vpc.id

  # VPC 내부에서 들어오는 모든 TCP 허용 (노드끼리 통신 + DNS + kube-proxy 등)
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.kt-cloud-vpc.cidr_block]
  }

  # VPC 내부에서 들어오는 모든 UDP 허용 (CoreDNS UDP 포트 등)
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "udp"
    cidr_blocks = [aws_vpc.kt-cloud-vpc.cidr_block]
  }

  # VPC 내부의 ICMP (=ping) 허용 — 디버깅용
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [aws_vpc.kt-cloud-vpc.cidr_block]
  }

  # bastion 에서 SSH(22) 만 허용
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion-node-sg.id]
  }

  # K8s API 6443 은 인터넷 어디서든 접근 가능 (kubectl 사용 위해)
  # ⚠️ 운영 환경에서는 회사/VPN IP 만 허용하는 게 안전.
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # 모든 outbound (=노드에서 외부로 나가는 트래픽) 허용
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # -1 = 모든 프로토콜
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# ─── 10. cluster-node-sg 자기참조 규칙 (Calico CNI 용) ─────────────
# 위 ingress 들은 TCP/UDP/ICMP 만 허용함. 그런데 Calico 의 IPIP 캡슐화는 IP protocol 4 라
# TCP 도 UDP 도 아니야. 그래서 이 규칙 없으면 노드 간 Pod-to-Pod 통신이 막힘.
# protocol = "-1" 은 "모든 IP 프로토콜" 이라 IPIP 도 통과시킴.
resource "aws_security_group_rule" "cluster_node_self_ingress" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.cluster-node-sg.id
  source_security_group_id = aws_security_group.cluster-node-sg.id # 같은 SG 멤버끼리만 허용
}


# ─── 11. 내 IP 자동 조회 (bastion SSH 허용에 사용) ────────────────
# data 블록 = "AWS 에 만드는 게 아니라, 외부에서 정보 읽어오는" 행위.
# ifconfig.me 가 내 공인 IP 를 반환 → 그 IP 만 bastion SSH 허용.
data "http" "my_ip" {
  url = "https://ifconfig.me/ip"
}

# locals 블록 = "임시 변수 모음". 이 파일 안에서만 쓰는 짧은 별칭.
locals {
  # chomp(): 끝의 줄바꿈 제거. "203.0.113.5\n" → "203.0.113.5".
  # 그 뒤에 "/32" 붙여서 CIDR 표현으로 만듦 (= IP 1개만 매칭).
  my_ip_cidr = "${chomp(data.http.my_ip.response_body)}/32"
}


# ─── 12. bastion-node-sg : Bastion 용 방화벽 ──────────────────────
# Bastion 은 외부에서 들어오는 입구 역할이라 더 빡빡하게 — 내 IP 만 허용.
resource "aws_security_group" "bastion-node-sg" {
  name   = "bastion-node-sg"
  vpc_id = aws_vpc.kt-cloud-vpc.id

  # 내 IP 에서만 SSH 허용
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.my_ip_cidr]
  }

  # 내 IP 에서만 ping 허용
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [local.my_ip_cidr]
  }

  # 모든 outbound 허용
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
