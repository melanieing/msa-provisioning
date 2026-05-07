# ─────────────────────────────────────────────────────────────────────────
# cluster-stop.ps1
# ─────────────────────────────────────────────────────────────────────────
# 클러스터의 EC2 8대(master 3 + worker 3 + bastion 2)를 한 번에 stop.
#
# 효과:
#   stop 된 인스턴스는 시간당 과금 0. 단, EBS 디스크/EFS/NLB/NAT/EIP 는 계속 청구됨.
#   대략 시간당 525원 → 180원으로 약 65% 절감.
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

# 에러 발생 시 즉시 멈춤
$ErrorActionPreference = "Stop"

# 스크립트 위치 기준으로 terraform 폴더 경로 잡기
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TerraformDir = Join-Path $ScriptDir "..\terraform"

Write-Host ""
Write-Host "[1/3] Terraform output 에서 EC2 ID 목록 가져오는 중..." -ForegroundColor Cyan

# terraform output -raw 로 공백 구분된 ID 문자열 추출
Push-Location $TerraformDir
try {
    $InstanceIdsRaw = terraform output -raw cluster_instance_ids
    $Region = terraform output -raw aws_region
} finally {
    Pop-Location
}

# 공백으로 split → 배열
$InstanceIds = $InstanceIdsRaw -split '\s+' | Where-Object { $_ -ne '' }

if ($InstanceIds.Count -eq 0) {
    Write-Host "[ERROR] EC2 ID 를 찾지 못했어요. terraform apply 가 끝났는지 확인해주세요." -ForegroundColor Red
    exit 1
}

Write-Host "  region       : $Region"
Write-Host "  찾은 EC2 수  : $($InstanceIds.Count)"
Write-Host "  ID 들        :"
$InstanceIds | ForEach-Object { Write-Host "    - $_" }

Write-Host ""
Write-Host "[2/3] EC2 stop 명령 전송 중..." -ForegroundColor Cyan

# AWS CLI 의 stop-instances 호출. --instance-ids 는 공백 구분.
aws ec2 stop-instances --region $Region --instance-ids $InstanceIds | Out-Null

Write-Host "  stop 명령 전송 완료. (실제 정지는 약 30초~1분 걸림)"

Write-Host ""
Write-Host "[3/3] 인스턴스 상태 확인 중..." -ForegroundColor Cyan

# 현재 상태 한번 출력 (전이 중일 수 있음)
$Status = aws ec2 describe-instances --region $Region --instance-ids $InstanceIds `
    --query "Reservations[].Instances[].[InstanceId,State.Name]" --output text

Write-Host $Status
Write-Host ""
Write-Host "[완료] stop 명령 전송됨. 실제 stopped 상태가 될 때까지 잠시 기다려주세요." -ForegroundColor Green
Write-Host ""
Write-Host "       다시 켤 때: .\cluster-start.ps1" -ForegroundColor Yellow
