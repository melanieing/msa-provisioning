# ─────────────────────────────────────────────────────────────────────────
# modules/loadbalancer — K8s API 용 NLB
# ─────────────────────────────────────────────────────────────────────────
# K8s API 서버(6443) 를 외부에 노출하는 Network Load Balancer.
# kubeadm join 시 'NLB DNS:6443' 으로 접속 → 살아있는 master 로 분기.
#
# 왜 NLB (L4) ?
#   K8s API 통신은 mTLS (TCP 위 TLS) 라 ALB 는 호환 X. 그냥 TCP 라우팅만 하는 NLB.
# ─────────────────────────────────────────────────────────────────────────


# ─── EIP ×2 (NLB 의 외부 IP 고정용) ───────────────────────────────
resource "aws_eip" "nlb_a" {
  domain = "vpc"
}

resource "aws_eip" "nlb_b" {
  domain = "vpc"
}


# ─── NLB 본체 ─────────────────────────────────────────────────────
resource "aws_lb" "this" {
  name               = "${var.name_prefix}-nlb"
  internal           = false
  load_balancer_type = "network"

  subnet_mapping {
    subnet_id     = var.public_subnet_a_id
    allocation_id = aws_eip.nlb_a.id
  }
  subnet_mapping {
    subnet_id     = var.public_subnet_b_id
    allocation_id = aws_eip.nlb_b.id
  }
}


# ─── Target Group (master 3대 등록부) ─────────────────────────────
resource "aws_lb_target_group" "k8s_api" {
  name     = "k8s-api-tg"
  port     = 6443
  protocol = "TCP"
  vpc_id   = var.vpc_id

  health_check {
    protocol = "TCP"
    port     = "6443"
    interval = 10
  }
}


# ─── NLB Listener ─────────────────────────────────────────────────
resource "aws_lb_listener" "k8s_api" {
  load_balancer_arn = aws_lb.this.arn
  port              = 6443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.k8s_api.arn
  }
}


# ─── master 3대를 Target Group 에 attach ──────────────────────────
# var.master_instance_ids 는 길이 3 의 list 라고 가정 (compute 모듈 output).
resource "aws_lb_target_group_attachment" "masters" {
  count            = length(var.master_instance_ids)
  target_group_arn = aws_lb_target_group.k8s_api.arn
  target_id        = var.master_instance_ids[count.index]
  port             = 6443
}
