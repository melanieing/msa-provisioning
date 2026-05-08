# compute 모듈 입력 — 루트 + network + security 에서 받아옴

# ─── EC2 설정 ─────────────────────────────────────────────────────
variable "node_ami_id" {
  description = "EC2 AMI ID"
  type        = string
}

variable "master_instance_type" {
  description = "master EC2 인스턴스 타입"
  type        = string
}

variable "worker_instance_type" {
  description = "worker EC2 인스턴스 타입"
  type        = string
}

variable "bastion_instance_type" {
  description = "bastion EC2 인스턴스 타입"
  type        = string
}

variable "worker_ebs_size_gb" {
  description = "worker 추가 EBS 크기 (GiB)"
  type        = number
}

variable "node_root_volume_size_gb" {
  description = "K8s 노드 (master/worker) 의 root EBS 볼륨 크기. 8GB 는 containerd image 캐시로 가득 참 (이슈 H, 2026-05-10)."
  type        = number
  default     = 30
}

variable "az_a" {
  description = "AZ A (EBS 가 어느 AZ 에 살지 결정)"
  type        = string
}

variable "az_b" {
  description = "AZ B"
  type        = string
}

# ─── SSH / IAM ────────────────────────────────────────────────────
variable "ssh_key_name" {
  description = "AWS Key Pair 이름"
  type        = string
}

variable "ssh_public_key_path" {
  description = "로컬 SSH 공개키 경로 (file() 로 읽음)"
  type        = string
}

variable "node_iam_role_name" {
  description = "EC2 노드용 기존 IAM Role 이름 (콘솔에서 사전 생성)"
  type        = string
}

variable "node_iam_instance_profile_name" {
  description = "이 모듈이 만들 Instance Profile 이름"
  type        = string
}

# ─── network 모듈에서 받는 값 ─────────────────────────────────────
variable "private_subnet_a_id" {
  description = "AZ A 의 private subnet ID"
  type        = string
}

variable "private_subnet_b_id" {
  description = "AZ B 의 private subnet ID"
  type        = string
}

variable "public_subnet_a_id" {
  description = "AZ A 의 public subnet ID (bastion 용)"
  type        = string
}

variable "public_subnet_b_id" {
  description = "AZ B 의 public subnet ID (bastion 용)"
  type        = string
}

# ─── security 모듈에서 받는 값 ────────────────────────────────────
variable "cluster_node_sg_id" {
  description = "클러스터 노드용 SG ID"
  type        = string
}

variable "bastion_sg_id" {
  description = "Bastion 용 SG ID"
  type        = string
}
