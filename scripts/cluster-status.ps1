# ─────────────────────────────────────────────────────────────────────────
# cluster-status.ps1
# ─────────────────────────────────────────────────────────────────────────
# 클러스터의 EC2 8대 현재 상태를 한 줄씩 표시.
# AWS 비용 청구 의심될 때 빨리 확인용.
# ─────────────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

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
    Write-Host "[ERROR] No EC2 IDs found." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Region: $Region" -ForegroundColor Cyan
Write-Host ""

$Output = aws ec2 describe-instances --region $Region --instance-ids $InstanceIds `
    --query "Reservations[].Instances[].[InstanceId, Tags[?Key=='Name'].Value | [0], State.Name, PublicIpAddress, PrivateIpAddress]" `
    --output table

Write-Host $Output

Write-Host ""
Write-Host "Summary:" -ForegroundColor Cyan
$States = aws ec2 describe-instances --region $Region --instance-ids $InstanceIds `
    --query "Reservations[].Instances[].State.Name" --output text
$StatesArr = $States -split '\s+' | Where-Object { $_ -ne '' }

$Running = ($StatesArr | Where-Object { $_ -eq 'running' }).Count
$Stopped = ($StatesArr | Where-Object { $_ -eq 'stopped' }).Count
$Other   = $StatesArr.Count - $Running - $Stopped

Write-Host "  running : $Running" -ForegroundColor $(if ($Running -gt 0) { 'Yellow' } else { 'Gray' })
Write-Host "  stopped : $Stopped" -ForegroundColor $(if ($Stopped -gt 0) { 'Green' } else { 'Gray' })
if ($Other -gt 0) {
    Write-Host "  other   : $Other (likely transitioning)" -ForegroundColor Magenta
}

Write-Host ""
if ($Running -gt 0) {
    Write-Host "[!] EC2 running. Hourly cost ~553 KRW." -ForegroundColor Yellow
    Write-Host "    Stop: .\cluster-stop.ps1" -ForegroundColor Yellow
} elseif ($Stopped -eq $StatesArr.Count) {
    Write-Host "[OK] All stopped. EC2 cost = 0. (NAT/NLB/EBS still ~180 KRW/h)" -ForegroundColor Green
    Write-Host "     Start: .\cluster-start.ps1" -ForegroundColor Green
}
