# ─────────────────────────────────────────────────────────────────────────
# cluster-stop.ps1
# ─────────────────────────────────────────────────────────────────────────
# 클러스터의 EC2 8대(master 3 + worker 3 + bastion 2)를 한 번에 stop.
#
# 효과:
#   stop 된 인스턴스는 시간당 과금 0. 단, EBS 디스크/EFS/NLB/NAT/EIP 는 계속 청구됨.
#   대략 시간당 553원 → 180원으로 약 65% 절감.
#
# 사용법:
#   PowerShell 에서:
#     cd C:\Users\melan\ktcloudtechup\msa-provisioning\scripts
#     .\cluster-stop.ps1
#
# 사전 조건:
#   - AWS CLI 설치 + 'aws configure' 완료
#   - terraform apply 한 번 이상 실행됨 (output 에서 instance ID 추출)
#
# 다시 켤 때: .\cluster-start.ps1
# ─────────────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"

# Force UTF-8 console (defensive — works even if user's locale is non-UTF-8)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TerraformDir = Join-Path $ScriptDir "..\terraform"

Write-Host ""
Write-Host "[1/3] Reading EC2 IDs from Terraform output..." -ForegroundColor Cyan

Push-Location $TerraformDir
try {
    $InstanceIdsRaw = terraform output -raw cluster_instance_ids
    $Region = terraform output -raw aws_region
} finally {
    Pop-Location
}

$InstanceIds = $InstanceIdsRaw -split '\s+' | Where-Object { $_ -ne '' }

if ($InstanceIds.Count -eq 0) {
    Write-Host "[ERROR] No EC2 IDs found. Did you run terraform apply?" -ForegroundColor Red
    exit 1
}

Write-Host "  region        : $Region"
Write-Host "  instances     : $($InstanceIds.Count)"
Write-Host "  IDs:"
$InstanceIds | ForEach-Object { Write-Host "    - $_" }

Write-Host ""
Write-Host "[2/3] Sending stop-instances request..." -ForegroundColor Cyan

aws ec2 stop-instances --region $Region --instance-ids $InstanceIds | Out-Null

Write-Host "  Stop request sent. (actual stopped state takes ~30-60s)"

Write-Host ""
Write-Host "[3/3] Current instance states:" -ForegroundColor Cyan

$Status = aws ec2 describe-instances --region $Region --instance-ids $InstanceIds `
    --query "Reservations[].Instances[].[InstanceId,State.Name]" --output text

Write-Host $Status
Write-Host ""
Write-Host "[OK] Stop request sent. Wait a moment for instances to reach 'stopped'." -ForegroundColor Green
Write-Host ""
Write-Host "      To start again: .\cluster-start.ps1" -ForegroundColor Yellow
