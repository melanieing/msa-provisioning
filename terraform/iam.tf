# ─────────────────────────────────────────────────────────────────────────
# EC2 노드들이 AWS 권한을 받기 위한 "Instance Profile" 만들기.
#
# IAM 용어 빠르게:
#   - Role            : "이런 권한을 가진 역할" 정의
#   - Policy          : 권한 자체 (예: "ALB 만들 수 있음")
#   - Instance Profile: "Role 을 EC2 에 붙이는 어댑터"
#                       (AWS 룰: EC2 에 Role 직접 못 붙이고 Profile 통해서만 가능)
#
# 왜 EC2 에 권한이 필요?
#   - AWS Load Balancer Controller(LBC) 가 ALB/NLB 만들려면 AWS API 호출 권한 필요.
#   - LBC 가 도는 노드의 EC2 가 권한을 가져야 함.
#
# ⚠️ 주의:
#   ktcloud-cluster-node-role 자체는 이 Terraform 코드로 만들지 않음.
#   AWS 콘솔에서 미리 만들어 둬야 함 (README 의 'NLB을 클러스터에 등록하기 위한 IAM 롤' 참고).
#   여기서는 'data' 블록으로 "이미 있는 Role 을 읽어와서" 사용만 함.
# ─────────────────────────────────────────────────────────────────────────


# data 블록 = "AWS 에 만드는 게 아니라, 이미 있는 거 정보 읽어오기"
data "aws_iam_role" "ktcloud-cluster-node-role" {
  name = var.node_iam_role_name # 기본 'ktcloud-cluster-node-role'
}


# Instance Profile 생성. 위 Role 을 EC2 에 붙일 수 있게 어댑터로 감싸는 역할.
resource "aws_iam_instance_profile" "ktcloud-cluster-node-profile" {
  name = var.node_iam_instance_profile_name # 기본 'ktcloud-node-profile'
  role = data.aws_iam_role.ktcloud-cluster-node-role.name
}
