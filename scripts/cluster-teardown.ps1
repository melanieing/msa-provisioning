# ─────────────────────────────────────────────────────────────────────────
# cluster-teardown.ps1
# ─────────────────────────────────────────────────────────────────────────
# AWS 의 모든 인프라 영구 삭제. 비용 0 으로 만듦.
#
# ⚠️ 무엇을 지우나?
#   - VPC, Subnet, IGW, NAT, NLB, EIP
#   - EC2 8대 (영구 삭제, 'stop' 이 아님)
#   - EBS 디스크 4개 + EFS (저장된 데이터 모두 사라짐)
#   - Security Group, IAM Instance Profile (Role 자체는 유지)
#
# ⚠️ 클러스터 안의 데이터는?
#   - Argo CD sync 상태, K8s 매니페스트는 모두 사라짐.
#   - 하지만 GitOps 라서 다음 bootstrap 때 자동으로 다시 복원됨.
#
# 사용법:
#   .\cluster-teardown.ps1
#
# 다시 띄우려면: .\cluster-bootstrap.ps1
# ─────────────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TerraformDir = Join-Path $ScriptDir "..\terraform"

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
Write-Host " ⚠️  클러스터 전체 삭제" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
Write-Host ""
Write-Host "다음 AWS 리소스가 영구 삭제됩니다:" -ForegroundColor Yellow
Write-Host "  • VPC, Subnet ×4, IGW, NAT ×2, NLB, EIP ×4"
Write-Host "  • EC2 8대 (master 3 + worker 3 + bastion 2)"
Write-Host "  • EBS 디스크 4개 + EFS 1개 (저장 데이터 모두 사라짐)"
Write-Host "  • Security Group ×3, Instance Profile"
Write-Host ""
Write-Host "유지되는 것:" -ForegroundColor Gray
Write-Host "  • IAM Role 'ktcloud-cluster-node-role' (콘솔에서 만든 거라 Terraform 이 관리 안 함)"
Write-Host ""

# 사용자 확인
$Confirm = Read-Host "정말 진행할까요? 'yes' 입력 (그 외엔 취소)"
if ($Confirm -ne "yes") {
    Write-Host ""
    Write-Host "취소됨." -ForegroundColor Gray
    exit 0
}

Write-Host ""
Write-Host "[1/1] terraform destroy 진행 중... (~5분)" -ForegroundColor Cyan
Write-Host ""

Push-Location $TerraformDir
try {
    terraform destroy -auto-approve
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "[ERROR] terraform destroy 실패." -ForegroundColor Red
        Write-Host ""
        Write-Host "흔한 원인: 클러스터 안의 Argo CD/AWS LBC 가 만든 ALB/NLB 가" -ForegroundColor Yellow
        Write-Host "VPC 를 사용 중이라 Terraform 이 VPC 못 지우는 경우." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "해결법:" -ForegroundColor Yellow
        Write-Host "  AWS 콘솔 → EC2 → Load Balancers 에서 'kt-cloud-' 가 아닌" -ForegroundColor Yellow
        Write-Host "  나머지 ALB/NLB 들을 손으로 지운 후 다시 .\cluster-teardown.ps1 실행." -ForegroundColor Yellow
        throw "terraform destroy 실패."
    }
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host " ✅ 모든 AWS 리소스 삭제됨. 시간당 비용 0." -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host ""
Write-Host "📋 다시 띄울 때: .\cluster-bootstrap.ps1" -ForegroundColor Yellow
Write-Host ""
