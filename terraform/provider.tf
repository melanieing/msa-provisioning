# ─────────────────────────────────────────────────────────────────────────
# Terraform 자체와 AWS 공급자(provider) 의 "버전 + 사용 region" 을 정의.
#
# 이 파일이 없으면:
#   - Terraform 이 환경 변수(AWS_REGION) 나 ~/.aws/config 의 기본값을 추측해서 씀.
#   - 사람마다, 환경마다 다른 region 에 배포되는 사고 가능.
#
# 이 파일이 있으면:
#   - "이 인프라는 var.region 에 배포한다" 가 코드로 박힘.
#   - 다른 사람이 git clone 해서 terraform apply 해도 같은 region 에 배포됨.
# ─────────────────────────────────────────────────────────────────────────

terraform {
  # 사용할 Terraform CLI 의 최소 버전. 1.6 미만이면 에러 나면서 멈춤.
  required_version = ">= 1.6.0"

  # 이 Terraform 코드가 사용하는 외부 provider 들 목록.
  # provider 란? AWS, GCP, Azure 같은 클라우드를 조작하는 SDK 같은 거.
  required_providers {
    aws = {
      source  = "hashicorp/aws" # 공식 AWS provider (HashiCorp 가 만듦)
      version = "~> 5.60"       # 5.60.x 또는 그 이상의 5.x 만 허용 (6.x 자동 업그레이드 차단)
    }
    http = {
      source  = "hashicorp/http" # vpc.tf 의 'data "http" "my_ip"' 에서 사용
      version = "~> 3.4"
    }
    local = {
      source  = "hashicorp/local" # ansible.tf 의 'local_file' 리소스에서 사용
      version = "~> 2.5"
    }
  }
}

# AWS 공급자 설정 — 어떤 region 에 배포할지 + 모든 리소스에 자동으로 붙일 태그.
provider "aws" {
  region = var.region # variables.tf 의 region 변수 (기본값 ap-northeast-2)

  # 모든 AWS 리소스에 자동으로 붙는 태그.
  # 비용 추적/소유자 표시 용도. 기본값은 빈 map 이라 기존 인프라에 drift 안 남.
  default_tags {
    tags = var.default_tags
  }
}
