# ─────────────────────────────────────────────────────────────────────────
# modules/security — Security Group 모음
# ─────────────────────────────────────────────────────────────────────────
# 클러스터 노드용 + Bastion 용 SG.
# (EFS 용 SG 는 storage 모듈에 따로 있음.)
# ─────────────────────────────────────────────────────────────────────────


# ─── 내 IP 자동 조회 (bastion SSH 허용용) ──────────────────────────
data "http" "my_ip" {
  url = "https://ifconfig.me/ip"
}

locals {
  # "203.0.113.5\n" → "203.0.113.5/32"
  my_ip_cidr = "${chomp(data.http.my_ip.response_body)}/32"
}


# ─── cluster-node-sg : K8s 노드용 방화벽 ───────────────────────────
# VPC 내부 TCP/UDP/ICMP 전부 허용 + bastion SSH + K8s API 외부 노출.
resource "aws_security_group" "cluster_node" {
  name   = "cluster-node-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  ingress {
    from_port   = 6443 # K8s API
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # 운영에선 회사/VPN IP 만 허용 권장
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# ─── 자기참조 ingress (Calico IPIP 통과용) ─────────────────────────
# 위 ingress 들은 TCP/UDP/ICMP 만 허용. Calico 기본 모드인 IP-in-IP(protocol 4)
# 트래픽은 그래서 막힘 → 같은 SG 멤버끼리 모든 IP 프로토콜 허용 규칙 추가.
# 이 규칙 없으면 노드 간 Pod-to-Pod 통신이 안 됨.
resource "aws_security_group_rule" "cluster_node_self_ingress" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.cluster_node.id
  source_security_group_id = aws_security_group.cluster_node.id
}


# ─── bastion-node-sg : Bastion 용 방화벽 ──────────────────────────
# 내 IP 에서만 SSH/ICMP 허용. 외부 노출 최소화.
resource "aws_security_group" "bastion" {
  name   = "bastion-node-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.my_ip_cidr]
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [local.my_ip_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
