# ─────────────────────────────────────────────────────────────────────────
# modules/registry — ECR (컨테이너 이미지 저장소) + KMS 암호화 + lifecycle policy
# ─────────────────────────────────────────────────────────────────────────
# 4개 마이크로서비스마다 1개 ECR repository 만듦. KMS 로 저장 암호화.
# Lifecycle policy 로 오래된 이미지 자동 삭제 (비용 절감).
#
# K8s 가 이 ECR 에서 pull 하려면:
#   EC2 노드의 IAM Role 에 'AmazonEC2ContainerRegistryReadOnly' 정책 attach 필요.
#   이건 compute 모듈에서 처리됨 (이 모듈은 repository 만들기까지).
# ─────────────────────────────────────────────────────────────────────────


# ─── KMS 키 (ECR 전용, SSE 암호화) ────────────────────────────────
# PDF §5.3 의 "모든 EBS/S3/EFS 는 AWS KMS Customer Managed Key 로 SSE 암호화" 정책에
# ECR 도 같은 패턴 적용.
resource "aws_kms_key" "ecr" {
  description             = "${var.name_prefix}-ecr encryption"
  deletion_window_in_days = 7    # 삭제 후 복구 가능 기간 (7일이 최소)
  enable_key_rotation     = true # 1년마다 자동 키 회전
}

resource "aws_kms_alias" "ecr" {
  name          = "alias/${var.name_prefix}-ecr"
  target_key_id = aws_kms_key.ecr.key_id
}


# ─── ECR Repositories (4개) ───────────────────────────────────────
# for_each 로 var.repository_names 의 각 이름에 대해 repo 1개씩 생성.
resource "aws_ecr_repository" "this" {
  for_each = toset(var.repository_names)

  name                 = each.key
  image_tag_mutability = "MUTABLE" # latest 태그를 새 이미지로 갱신 가능

  # destroy 시 이미지 있어도 함께 삭제 (학습 환경 — 매일 destroy/bootstrap 워크플로 친화).
  # 운영 환경이라면 false 로 두고 별도 라이프사이클 정책으로 정리하는 게 안전.
  force_delete = true

  # push 시 자동 취약점 스캔 (Trivy 같은 외부 도구 없이도 기본 스캔)
  image_scanning_configuration {
    scan_on_push = true
  }

  # KMS 로 저장 암호화 (위에서 만든 키 사용)
  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.ecr.arn
  }
}


# ─── Lifecycle Policy: 오래된 이미지 자동 삭제 ────────────────────
# 비용 절감 + 저장소 정리. 두 정책:
#   1) untagged 이미지는 30개 초과 시 오래된 것부터 삭제
#   2) tagged 이미지도 50개 초과 시 오래된 것부터 삭제
resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 30 untagged images"
        selection = {
          tagStatus   = "untagged"
          countType   = "imageCountMoreThan"
          countNumber = 30
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep last 50 tagged images"
        selection = {
          tagStatus      = "tagged"
          tagPatternList = ["*"]
          countType      = "imageCountMoreThan"
          countNumber    = 50
        }
        action = { type = "expire" }
      }
    ]
  })
}
