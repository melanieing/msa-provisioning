# ─────────────────────────────────────────────────────────────────────────
# 이 파일은 뭐 하는 파일?
# ─────────────────────────────────────────────────────────────────────────
# Ansible 이 사용할 'inventory.ini' 파일을 자동 생성.
#
# inventory.ini 가 뭔데?
#   Ansible 에게 "어떤 호스트가 있고, 어떤 그룹에 속하고, 어떻게 SSH 접속하는지"
#   알려주는 파일. 그룹별로 노드 IP 등을 정리해둠.
#
# 왜 자동 생성?
#   EC2 의 사설 IP 는 terraform apply 마다 달라질 수 있음 (또는 재생성 시 바뀜).
#   매번 손으로 inventory.ini 갱신하면 실수하기 쉬워서 Terraform 이 직접 만들게 함.
#
# 동작:
#   1) inventory.tftpl 템플릿 파일을 읽음
#   2) 아래 templatefile() 의 두 번째 인자(map)에 있는 변수들을 ${} 자리에 치환
#   3) 결과를 ../ansible/inventory.ini 로 저장
# ─────────────────────────────────────────────────────────────────────────

resource "local_file" "ansible_inventory" {
  content = templatefile("inventory.tftpl", {
    # 이 map 의 key = 템플릿 안의 ${...} 변수 이름
    bastion_a_ip                   = aws_instance.ap-northeast-2a-bastion-node.public_ip
    bastion_b_ip                   = aws_instance.ap-northeast-2b-bastion-node.public_ip
    ap-northeast-2a-master-node-01 = aws_instance.ap-northeast-2a-master-node-01.private_ip
    ap-northeast-2a-master-node-02 = aws_instance.ap-northeast-2a-master-node-02.private_ip
    ap-northeast-2a-worker-node-01 = aws_instance.ap-northeast-2a-worker-node-01.private_ip
    ap-northeast-2b-master-node-01 = aws_instance.ap-northeast-2b-master-node-01.private_ip
    ap-northeast-2b-worker-node-01 = aws_instance.ap-northeast-2b-worker-node-01.private_ip
    ap-northeast-2b-worker-node-02 = aws_instance.ap-northeast-2b-worker-node-02.private_ip
    ktcloud-nlb-ip                 = aws_lb.kt-cloud-nlb.dns_name
    vpc_id                         = aws_vpc.kt-cloud-vpc.id
    ssh_private_key_path           = var.ssh_private_key_path # 변수화 후 추가됨
  })
  filename = "${path.module}/../ansible/inventory.ini" # ../ansible/inventory.ini 에 저장
}
