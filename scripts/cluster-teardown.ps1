# ─────────────────────────────────────────────────────────────────────────
# cluster-teardown.ps1
# ─────────────────────────────────────────────────────────────────────────
# AWS 의 모든 인프라 영구 삭제. 비용 0 으로 만듦.
# 자세한 설명은 scripts/README.md 참고.
# ─────────────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TerraformDir = Join-Path $ScriptDir "..\terraform"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host " [WARNING] Permanent cluster teardown" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "These AWS resources will be PERMANENTLY DELETED:" -ForegroundColor Yellow
Write-Host "  - VPC, Subnets x4, IGW, NAT x2, NLB, EIP x4"
Write-Host "  - EC2 8 instances (master 3 + worker 3 + bastion 2)"
Write-Host "  - EBS volumes x4 + EFS x1 (all data lost)"
Write-Host "  - Security Groups x3, Instance Profile"
Write-Host "  - ECR repositories x4 (all images lost)"
Write-Host "  - KMS key, GitHub OIDC provider, IAM Role for Actions"
Write-Host ""
Write-Host "Preserved (not managed by Terraform):" -ForegroundColor Gray
Write-Host "  - IAM Role 'ktcloud-cluster-node-role' (created via console/CLI)"
Write-Host ""

$Confirm = Read-Host "Proceed? Type 'yes' to confirm"
if ($Confirm -ne "yes") {
    Write-Host ""
    Write-Host "Cancelled." -ForegroundColor Gray
    exit 0
}

Write-Host ""
Write-Host "[1/1] Running terraform destroy (~5 min)..." -ForegroundColor Cyan
Write-Host ""

Push-Location $TerraformDir
try {
    terraform destroy -auto-approve
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "[ERROR] terraform destroy failed." -ForegroundColor Red
        Write-Host ""
        Write-Host "Common cause: Argo CD / AWS LBC created ALB/NLB inside the cluster" -ForegroundColor Yellow
        Write-Host "that are still using the VPC, blocking VPC deletion." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Fix:" -ForegroundColor Yellow
        Write-Host "  AWS Console -> EC2 -> Load Balancers" -ForegroundColor Yellow
        Write-Host "  Delete any ALB/NLB other than 'kt-cloud-nlb', then retry." -ForegroundColor Yellow
        throw "terraform destroy failed."
    }
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " [OK] All AWS resources deleted. Hourly cost = 0." -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "To bring it back: .\cluster-bootstrap.ps1" -ForegroundColor Yellow
Write-Host ""
