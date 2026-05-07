# ─────────────────────────────────────────────────────────────────────────
# modules/github-oidc — GitHub Actions ↔ AWS 무패스워드 페더레이션
# ─────────────────────────────────────────────────────────────────────────
# 무엇을 하나?
#   GitHub Actions 워크플로가 AWS 에 "나는 melanieing/msa-spring-boot 의 main
#   브랜치 워크플로야" 라고 자기 신원(ID 토큰)을 제시하면, AWS 가 검증 후
#   임시 자격증명을 발급해줌. 그러면 Actions 가 ECR push 가능.
#
# 이게 왜 좋아?
#   - GitHub Secrets 에 AWS access key 박지 않아도 됨 (장기 키 유출 위험 0)
#   - 임시 자격증명만 받아서 그 워크플로 실행 시간만 유효
#   - 시니어 DevOps 의 표준 패턴
#
# 구성요소 3개:
#   1) OIDC Identity Provider (AWS 가 GitHub 의 ID 토큰을 신뢰하게 등록)
#   2) IAM Role (Actions 가 assume 할 역할)
#   3) Trust Policy (어떤 GitHub repo + branch 만 이 role 을 쓸 수 있는지 제한)
# ─────────────────────────────────────────────────────────────────────────


# ─── 1. OIDC Identity Provider ────────────────────────────────────
# AWS 계정에 GitHub OIDC 를 한 번만 등록. 이미 다른 작업에서 등록돼 있으면
# 이 resource 가 conflict — 그 경우 'terraform import' 또는 data 사용.
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  # GitHub OIDC 의 신뢰 thumbprint (공인 인증서 fingerprint).
  # AWS 가 GitHub 의 토큰 서명을 검증할 때 사용. 두 값 다 잘 알려진 GitHub 공식 값.
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]
}


# ─── 2. Trust Policy (누가 이 role 을 쓸 수 있나) ────────────────
# 핵심 보안 포인트: 'sub' condition 으로 특정 repo + branch 만 허용.
# 이거 없으면 GitHub 의 어떤 repo 든 우리 AWS 에 접근 가능 → 심각한 보안 구멍.
data "aws_iam_policy_document" "trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    # audience 검증 — 이 토큰이 AWS STS 용인지 확인
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # subject 검증 — 정확히 어떤 repo/branch 에서 온 토큰인지 매칭
    # 'repo:OWNER/REPO:ref:refs/heads/BRANCH' 형식
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_owner}/${var.github_repo}:ref:refs/heads/main",
        "repo:${var.github_owner}/${var.github_repo}:ref:refs/heads/claude/*",
        # 필요 시 PR 워크플로용도 추가 가능:
        # "repo:${var.github_owner}/${var.github_repo}:pull_request",
      ]
    }
  }
}


# ─── 3. IAM Role (Actions 가 assume 할 역할) ─────────────────────
resource "aws_iam_role" "github_actions" {
  name               = "${var.name_prefix}-github-actions-role"
  assume_role_policy = data.aws_iam_policy_document.trust.json

  tags = {
    Purpose = "GitHub Actions OIDC federation for ECR push"
  }
}


# ─── 4. ECR Push Policy ────────────────────────────────────────────
# 이 role 이 할 수 있는 일: ECR 인증 토큰 받기 + 우리 repo 들에 image push.
# 다른 AWS 리소스는 못 건드림 (least privilege).
data "aws_iam_policy_document" "ecr_push" {
  # ECR 인증 토큰은 모든 repo 공통이라 resource = "*"
  statement {
    sid       = "EcrAuthToken"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # 실제 push/pull 은 우리 repo 들에만 허용
  statement {
    sid    = "EcrPushPull"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
    ]
    resources = var.ecr_repository_arns
  }
}

resource "aws_iam_role_policy" "ecr_push" {
  name   = "ecr-push"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.ecr_push.json
}
