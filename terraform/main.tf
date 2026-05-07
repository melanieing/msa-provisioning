# ─────────────────────────────────────────────────────────────────────────
# 루트 main.tf — 5개 모듈을 인스턴스화하고 서로 연결
# ─────────────────────────────────────────────────────────────────────────
# 이 파일이 전체 그림. 어떤 인프라를 어떤 순서로 만들지 한눈에 보임.
#
#   network  → security  → compute  → loadbalancer → storage
#                            ↑              ↑
#                            └──── master IDs ─────┘
#
# Terraform 은 module 끼리의 의존성(어느 게 어떤 output 을 쓰는지)을 자동 분석해서
# 알아서 올바른 순서로 생성/삭제함.
# ─────────────────────────────────────────────────────────────────────────


# ─── 1. 네트워크 (VPC, Subnet, IGW, NAT, Route Table) ─────────────
module "network" {
  source = "./modules/network"

  vpc_cidr              = var.vpc_cidr
  az_a                  = var.az_a
  az_b                  = var.az_b
  public_subnet_a_cidr  = var.public_subnet_a_cidr
  private_subnet_a_cidr = var.private_subnet_a_cidr
  public_subnet_b_cidr  = var.public_subnet_b_cidr
  private_subnet_b_cidr = var.private_subnet_b_cidr
}


# ─── 2. 방화벽 (cluster-node-sg, bastion-node-sg) ─────────────────
module "security" {
  source = "./modules/security"

  vpc_id   = module.network.vpc_id
  vpc_cidr = module.network.vpc_cidr_block
}


# ─── 3. 컴퓨팅 (EC2 ×8 + EBS + Key Pair + Instance Profile) ───────
module "compute" {
  source = "./modules/compute"

  # 루트에서 받는 값
  node_ami_id                    = var.node_ami_id
  master_instance_type           = var.master_instance_type
  worker_instance_type           = var.worker_instance_type
  bastion_instance_type          = var.bastion_instance_type
  worker_ebs_size_gb             = var.worker_ebs_size_gb
  az_a                           = var.az_a
  az_b                           = var.az_b
  ssh_key_name                   = var.ssh_key_name
  ssh_public_key_path            = var.ssh_public_key_path
  node_iam_role_name             = var.node_iam_role_name
  node_iam_instance_profile_name = var.node_iam_instance_profile_name

  # network 모듈에서 받는 값
  private_subnet_a_id = module.network.private_subnet_a_id
  private_subnet_b_id = module.network.private_subnet_b_id
  public_subnet_a_id  = module.network.public_subnet_a_id
  public_subnet_b_id  = module.network.public_subnet_b_id

  # security 모듈에서 받는 값
  cluster_node_sg_id = module.security.cluster_node_sg_id
  bastion_sg_id      = module.security.bastion_sg_id
}


# ─── 4. 로드밸런서 (K8s API 용 NLB) ───────────────────────────────
module "loadbalancer" {
  source = "./modules/loadbalancer"

  name_prefix        = var.name_prefix
  vpc_id             = module.network.vpc_id
  public_subnet_a_id = module.network.public_subnet_a_id
  public_subnet_b_id = module.network.public_subnet_b_id

  # compute 모듈의 master EC2 ID 들을 NLB target 으로 등록
  master_instance_ids = [
    module.compute.master_a01_id,
    module.compute.master_a02_id,
    module.compute.master_b01_id,
  ]
}


# ─── 5. 공유 스토리지 (EFS) ───────────────────────────────────────
module "storage" {
  source = "./modules/storage"

  name_prefix         = var.name_prefix
  vpc_id              = module.network.vpc_id
  vpc_cidr            = module.network.vpc_cidr_block
  private_subnet_a_id = module.network.private_subnet_a_id
  private_subnet_b_id = module.network.private_subnet_b_id
}
