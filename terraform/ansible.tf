# ─────────────────────────────────────────────────────────────────────────
# Ansible 이 사용할 'inventory.ini' 를 자동 생성.
# inventory.tftpl 템플릿을 읽어서 ${...} 자리에 모듈 outputs (IP 등) 채워서 저장.
# ─────────────────────────────────────────────────────────────────────────

resource "local_file" "ansible_inventory" {
  content = templatefile("inventory.tftpl", {
    # 이 map 의 key = 템플릿 안의 ${...} 변수 이름
    bastion_a_ip                   = module.compute.bastion_a_public_ip
    bastion_b_ip                   = module.compute.bastion_b_public_ip
    ap-northeast-2a-master-node-01 = module.compute.master_a01_private_ip
    ap-northeast-2a-master-node-02 = module.compute.master_a02_private_ip
    ap-northeast-2a-worker-node-01 = module.compute.worker_a01_private_ip
    ap-northeast-2b-master-node-01 = module.compute.master_b01_private_ip
    ap-northeast-2b-worker-node-01 = module.compute.worker_b01_private_ip
    ap-northeast-2b-worker-node-02 = module.compute.worker_b02_private_ip
    ktcloud-nlb-ip                 = module.loadbalancer.nlb_dns_name
    vpc_id                         = module.network.vpc_id
    ssh_private_key_path           = var.ssh_private_key_path
  })
  filename = "${path.module}/../ansible/inventory.ini"
}
