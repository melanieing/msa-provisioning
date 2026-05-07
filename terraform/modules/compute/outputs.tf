# compute 모듈 출력 — 다른 모듈/루트가 참조

# ─── master ID (loadbalancer 의 target 으로 사용) ─────────────────
output "master_a01_id" {
  value = aws_instance.ap-northeast-2a-master-node-01.id
}

output "master_a02_id" {
  value = aws_instance.ap-northeast-2a-master-node-02.id
}

output "master_b01_id" {
  value = aws_instance.ap-northeast-2b-master-node-01.id
}


# ─── master/worker private IP (ansible inventory 에 사용) ─────────
output "master_a01_private_ip" {
  value = aws_instance.ap-northeast-2a-master-node-01.private_ip
}

output "master_a02_private_ip" {
  value = aws_instance.ap-northeast-2a-master-node-02.private_ip
}

output "master_b01_private_ip" {
  value = aws_instance.ap-northeast-2b-master-node-01.private_ip
}

output "worker_a01_private_ip" {
  value = aws_instance.ap-northeast-2a-worker-node-01.private_ip
}

output "worker_b01_private_ip" {
  value = aws_instance.ap-northeast-2b-worker-node-01.private_ip
}

output "worker_b02_private_ip" {
  value = aws_instance.ap-northeast-2b-worker-node-02.private_ip
}


# ─── bastion 공인 IP (SSH 접속용) ─────────────────────────────────
output "bastion_a_public_ip" {
  value = aws_instance.ap-northeast-2a-bastion-node.public_ip
}

output "bastion_b_public_ip" {
  value = aws_instance.ap-northeast-2b-bastion-node.public_ip
}


# ─── 모든 EC2 ID 목록 (cluster-stop/start 스크립트가 사용) ────────
output "all_instance_ids" {
  description = "EC2 8대 ID 모두 (공백 구분 문자열, 비용 절감 스크립트용)"
  value = join(" ", [
    aws_instance.ap-northeast-2a-master-node-01.id,
    aws_instance.ap-northeast-2a-master-node-02.id,
    aws_instance.ap-northeast-2b-master-node-01.id,
    aws_instance.ap-northeast-2a-worker-node-01.id,
    aws_instance.ap-northeast-2b-worker-node-01.id,
    aws_instance.ap-northeast-2b-worker-node-02.id,
    aws_instance.ap-northeast-2a-bastion-node.id,
    aws_instance.ap-northeast-2b-bastion-node.id,
  ])
}
