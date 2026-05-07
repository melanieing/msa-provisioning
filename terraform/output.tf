# ─────────────────────────────────────────────────────────────────────────
# 이 파일은 뭐 하는 파일?
# ─────────────────────────────────────────────────────────────────────────
# terraform apply 끝난 후 화면에 출력될 정보.
# 여기서는 "그래서 어떻게 SSH 접속해?" 하는 명령어를 바로 복붙 가능하게 만들어줘.
#
# 예시 출력:
#   ap-northeast-2a-bastion-node-connect-command =
#     "ssh ec2-user@13.125.7.2 -i ~/.ssh/ktcloud-bastion-node-key"
#
# ProxyJump (-J) 사용법:
#   bastion 통해 master 에 한 번에 접속 → "-A -J bastion@공인IP master@사설IP"
#   -A: SSH 에이전트 포워딩 (key 들고 다님)
#   -J: 점프 호스트 지정
# ─────────────────────────────────────────────────────────────────────────


# AZ A 의 bastion 으로 접속하는 ssh 명령어
output "ap-northeast-2a-bastion-node-connect-command" {
  value = "ssh ec2-user@${aws_instance.ap-northeast-2a-bastion-node.public_ip} -i ${var.ssh_private_key_path}"
}


# AZ B 의 bastion 접속 명령어
output "ap-northeast-2b-bastion-node-connect-command" {
  value = "ssh ec2-user@${aws_instance.ap-northeast-2b-bastion-node.public_ip} -i ${var.ssh_private_key_path}"
}


# kubeadm init 을 실행할 main-master 에 한 번에 접속 (bastion 경유)
output "main-master-node-connect-command" {
  value = "ssh -A -J ec2-user@${aws_instance.ap-northeast-2b-bastion-node.public_ip} ec2-user@${aws_instance.ap-northeast-2b-master-node-01.private_ip}"
}
