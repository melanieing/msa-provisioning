# ─────────────────────────────────────────────────────────────────────────
# cluster-status.ps1
# ─────────────────────────────────────────────────────────────────────────
# 클러스터의 EC2 8대 현재 상태를 한 줄씩 표시.
# AWS 비용 청구 의심될 때 빨리 확인용.
#
# 출력 예시:
#   InstanceId           Name              State       PublicIP
#   i-0123456789abcdef0  a-master-01       stopped     -
#   i-0fedcba9876543210  a-worker-01       running     -
#   ...
#
# 사용법:
#     .\cluster-status.ps1
# ─────────────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TerraformDir = Join-Path $ScriptDir "..\terraform"

Push-Location $TerraformDir
try {
    $InstanceIdsRaw = terraform output -raw cluster_instance_ids
    $Region = terraform output -raw aws_region
} finally {
    Pop-Location
}

$InstanceIds = $InstanceIdsRaw -split '\s+' | Where-Object { $_ -ne '' }

if ($InstanceIds.Count -eq 0) {
    Write-Host "[ERROR] EC2 ID 를 찾지 못했어요." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Region: $Region" -ForegroundColor Cyan
Write-Host ""

# describe-instances 로 정보 받아서 표 형식으로 출력
# Name 태그가 없을 수도 있으니 'Tags[?Key==Name].Value | [0]' 로 안전하게 추출
$Output = aws ec2 describe-instances --region $Region --instance-ids $InstanceIds `
    --query "Reservations[].Instances[].[InstanceId, Tags[?Key=='Name'].Value | [0], State.Name, PublicIpAddress, PrivateIpAddress]" `
    --output table

Write-Host $Output

# 현재 상태별 카운트
Write-Host ""
Write-Host "요약:" -ForegroundColor Cyan
$States = aws ec2 describe-instances --region $Region --instance-ids $InstanceIds `
    --query "Reservations[].Instances[].State.Name" --output text
$StatesArr = $States -split '\s+' | Where-Object { $_ -ne '' }

$Running = ($StatesArr | Where-Object { $_ -eq 'running' }).Count
$Stopped = ($StatesArr | Where-Object { $_ -eq 'stopped' }).Count
$Other   = $StatesArr.Count - $Running - $Stopped

Write-Host "  running : $Running" -ForegroundColor $(if ($Running -gt 0) { 'Yellow' } else { 'Gray' })
Write-Host "  stopped : $Stopped" -ForegroundColor $(if ($Stopped -gt 0) { 'Green' } else { 'Gray' })
if ($Other -gt 0) {
    Write-Host "  기타    : $Other (전이 중일 가능성)" -ForegroundColor Magenta
}

Write-Host ""
if ($Running -gt 0) {
    Write-Host "💡 EC2 켜져있는 동안 시간당 약 525원 청구 중." -ForegroundColor Yellow
    Write-Host "   끄려면: .\cluster-stop.ps1" -ForegroundColor Yellow
} elseif ($Stopped -eq $StatesArr.Count) {
    Write-Host "💡 모두 stopped — EC2 비용 0. (NAT/NLB/EBS 는 계속 약 시간당 180원)" -ForegroundColor Green
    Write-Host "   다시 켤 때: .\cluster-start.ps1" -ForegroundColor Green
}
