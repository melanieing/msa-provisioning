# ─────────────────────────────────────────────────────────────────────────
# 루트 output — 모듈 outputs 를 사용자에게 노출
# ─────────────────────────────────────────────────────────────────────────
# 'terraform apply' 끝나면 화면에 출력됨. SSH 명령어, 비용 절감 스크립트가 사용.
# ─────────────────────────────────────────────────────────────────────────


# ─── SSH 접속 명령어 (편의용) ─────────────────────────────────────

output "ap-northeast-2a-bastion-node-connect-command" {
  value = "ssh ec2-user@${module.compute.bastion_a_public_ip} -i ${var.ssh_private_key_path}"
}

output "ap-northeast-2b-bastion-node-connect-command" {
  value = "ssh ec2-user@${module.compute.bastion_b_public_ip} -i ${var.ssh_private_key_path}"
}

# kubeadm init 을 실행할 main-master 에 한 번에 접속 (bastion 경유)
output "main-master-node-connect-command" {
  value = "ssh -A -J ec2-user@${module.compute.bastion_b_public_ip} ec2-user@${module.compute.master_b01_private_ip}"
}


# ─── 비용 절감 스크립트(scripts/cluster-stop.ps1 등) 가 사용 ──────

output "cluster_instance_ids" {
  description = "EC2 8대 ID 모두 (공백 구분 문자열). 'terraform output -raw cluster_instance_ids' 로 추출."
  value       = module.compute.all_instance_ids
}

output "aws_region" {
  description = "AWS region — 스크립트가 'aws ec2 stop-instances --region <X>' 호출 시 사용."
  value       = var.region
}
