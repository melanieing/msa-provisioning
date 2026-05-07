# ─────────────────────────────────────────────────────────────────────────
# 이 파일은 뭐 하는 파일이야?
# ─────────────────────────────────────────────────────────────────────────
# Terraform 코드가 받을 수 있는 "입력값(변수)" 들의 목록과 기본값을 적어둔 곳.
#
# 변수가 있으면 좋은 점:
#   - 여러 .tf 파일에 흩어진 값들을 한곳에서 관리.
#   - 다른 region/계정에서 재사용하기 쉬움.
#   - "이 인프라가 받을 수 있는 옵션이 뭐인지" 한눈에 보임.
#
# 사용 방법:
#   - 그냥 'terraform apply' 하면 모든 변수가 default 값을 사용 → 기존 동작 그대로.
#   - 값을 바꾸고 싶으면 'terraform.tfvars' 파일 만들어서 적기:
#       master_instance_type = "t3.small"
#       worker_instance_type = "t3.small"
#   - tfvars 는 .gitignore 에 들어있어서 실수로 커밋 안 됨.
#
# 알려진 한계 (정직 선언):
#   각 .tf 파일의 리소스 이름표(예: "ap-northeast-2a-master-node-01") 에는 region/AZ 가
#   여전히 하드코딩 되어 있어. var.region 만 바꿔도 이름표는 그대로라서, 정말 다른 region
#   으로 옮기려면 이름표 리팩터링이 별도로 필요해. (이번 작업 범위 밖)
# ─────────────────────────────────────────────────────────────────────────


# ─────────────────────────────────────────────────────────────────────────
# 일반 / 이름 짓기
# ─────────────────────────────────────────────────────────────────────────

variable "region" {
  description = "AWS region. 모든 리소스가 여기에 만들어짐."
  type        = string
  default     = "ap-northeast-2" # 서울 region
}

variable "name_prefix" {
  description = "공유 리소스 이름 앞에 붙일 접두어 (NLB, EFS 같은 데). 'kt-cloud-nlb' 처럼 조합됨."
  type        = string
  default     = "kt-cloud"
}

variable "default_tags" {
  description = "AWS 모든 리소스에 자동으로 붙을 태그. 기본은 빈 map (기존 인프라에 drift 방지). tfvars 에서 활성화 가능."
  type        = map(string)
  default     = {}
}


# ─────────────────────────────────────────────────────────────────────────
# 네트워크 (VPC / Subnet)
# ─────────────────────────────────────────────────────────────────────────
# 용어 빠르게:
#   VPC      — AWS 안에 만드는 사설 네트워크 (내 전용 가상 네트워크 박스)
#   Subnet   — VPC 를 잘라낸 작은 구역. 보통 AZ(가용영역) 별로 1~2개씩.
#   public   — 인터넷에서 직접 접근 가능 (NAT/IGW 가 여기 있음)
#   private  — 인터넷 직접 접근 X. 노드/DB 가 여기 살음.
# ─────────────────────────────────────────────────────────────────────────

variable "vpc_cidr" {
  description = "VPC 전체에 할당할 IP 대역. /16 이면 약 65,536 개 IP 사용 가능."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_a" {
  description = "AZ A. 서울 region 에서는 ap-northeast-2a 같은 첫 번째 가용영역."
  type        = string
  default     = "ap-northeast-2a"
}

variable "az_b" {
  description = "AZ B. 두 번째 가용영역. 한 AZ 다운돼도 서비스 살아있게 하려고 분산."
  type        = string
  default     = "ap-northeast-2b"
}

variable "public_subnet_a_cidr" {
  description = "AZ A 의 public subnet IP 대역. NAT/Bastion 이 여기 살음."
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_a_cidr" {
  description = "AZ A 의 private subnet IP 대역. K8s master/worker 가 여기 살음."
  type        = string
  default     = "10.0.2.0/24"
}

variable "public_subnet_b_cidr" {
  description = "AZ B 의 public subnet IP 대역."
  type        = string
  default     = "10.0.3.0/24"
}

variable "private_subnet_b_cidr" {
  description = "AZ B 의 private subnet IP 대역."
  type        = string
  default     = "10.0.4.0/24"
}


# ─────────────────────────────────────────────────────────────────────────
# 컴퓨팅 (EC2 인스턴스)
# ─────────────────────────────────────────────────────────────────────────
# 비용 메모: t3.medium 1대 ≈ $0.0416/hr (≈ 55원/시간)
#           t3.small  1대 ≈ $0.0208/hr (≈ 28원/시간) — 절반 가격
#           t3.nano   1대 ≈ $0.0052/hr (≈  7원/시간) — bastion 정도면 충분
# ─────────────────────────────────────────────────────────────────────────

variable "node_ami_id" {
  description = "EC2 인스턴스 OS 이미지(AMI). 기본은 서울 region 의 Amazon Linux 2."
  type        = string
  default     = "ami-087e08db3e40f7429"
}

variable "master_instance_type" {
  description = "K8s 컨트롤플레인(master) EC2 타입. 3대 띄움. (HA 구성)"
  type        = string
  default     = "t3.medium"
}

variable "worker_instance_type" {
  description = "K8s 워커 노드 EC2 타입. 3대 띄움."
  type        = string
  default     = "t3.medium"
}

variable "bastion_instance_type" {
  description = "Bastion(점프 호스트) EC2 타입. AZ 마다 1대씩 총 2대. 작은 거로 충분."
  type        = string
  default     = "t3.nano"
}

variable "worker_ebs_size_gb" {
  description = "워커 노드에 추가로 붙는 EBS 디스크 용량 (GiB). PVC 용으로 쓰일 예정."
  type        = number
  default     = 20
}


# ─────────────────────────────────────────────────────────────────────────
# IAM (권한) / SSH
# ─────────────────────────────────────────────────────────────────────────

variable "node_iam_role_name" {
  description = "EC2 노드가 쓸 IAM Role 이름. ⚠️ 이 Role 은 Terraform 으로 만들지 않음 — AWS 콘솔에서 미리 만들어 둬야 함 (README 참고)."
  type        = string
  default     = "ktcloud-cluster-node-role"
}

variable "node_iam_instance_profile_name" {
  description = "위 Role 을 EC2 에 붙이기 위해 만드는 Instance Profile 이름. (Role 을 EC2 에 직접 못 붙임 — Profile 통해서만 가능한 AWS 룰)"
  type        = string
  default     = "ktcloud-node-profile"
}

variable "ssh_key_name" {
  description = "AWS 에 등록할 키페어 이름. 모든 EC2 가 이 키로 SSH 접속됨."
  type        = string
  default     = "ktcloud-bastion-node-key"
}

variable "ssh_public_key_path" {
  description = "AWS 에 업로드할 공개키 파일 경로. ssh-key-gen.bash 가 이 위치에 키 만들어둠."
  type        = string
  default     = "~/.ssh/ktcloud-bastion-node-key.pub"
}

variable "ssh_private_key_path" {
  description = "내 컴퓨터의 SSH 개인키 위치. AWS 에 업로드 X — 단지 inventory.ini, output 에 SSH 명령어 쓸 때만 사용."
  type        = string
  default     = "~/.ssh/ktcloud-bastion-node-key"
}
