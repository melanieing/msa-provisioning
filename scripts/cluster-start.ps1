# ─────────────────────────────────────────────────────────────────────────
# cluster-start.ps1
# ─────────────────────────────────────────────────────────────────────────
# 클러스터의 EC2 8대를 한 번에 start.
#
# ⚠️ 중요: bastion 의 public IP 는 stop/start 시 변경됨.
#         (NAT 의 EIP 는 고정이지만 bastion 은 자동 할당 IP 라서)
#         start 후 'terraform apply' 를 한번 더 돌려야 inventory.ini 가 갱신되어
#         Ansible/SSH 가 정상 동작함.
#
# 사용법:
#     cd C:\Users\melan\ktcloudtechup\msa-provisioning\scripts
#     .\cluster-start.ps1
#
# 시작 후 K8s 가 다시 정상 동작하는 데 약 2~3분 더 걸림 (kubelet/etcd 재기동).
# ─────────────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TerraformDir = Join-Path $ScriptDir "..\terraform"

Write-Host ""
Write-Host "[1/4] Reading EC2 IDs from Terraform output..." -ForegroundColor Cyan

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

Write-Host "  region    : $Region"
Write-Host "  instances : $($InstanceIds.Count)"

Write-Host ""
Write-Host "[2/4] Sending start-instances request..." -ForegroundColor Cyan

aws ec2 start-instances --region $Region --instance-ids $InstanceIds | Out-Null
Write-Host "  Start request sent."

Write-Host ""
Write-Host "[3/4] Waiting for instances to reach 'running' state (~30-60s)..." -ForegroundColor Cyan

aws ec2 wait instance-running --region $Region --instance-ids $InstanceIds
Write-Host "  All instances are now running."

Write-Host ""
Write-Host "[4/4] Re-running terraform apply to refresh inventory.ini..." -ForegroundColor Cyan
Write-Host "      (bastion public IP may have changed; inventory needs to follow)"
Write-Host ""

Push-Location $TerraformDir
try {
    terraform apply -auto-approve
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "[OK] Cluster is back up." -ForegroundColor Green
Write-Host ""
Write-Host "      Next steps:" -ForegroundColor Yellow
Write-Host "      - Wait 2-3 minutes for K8s to be Ready (kubelet/etcd restart)"
Write-Host "      - SSH to main-master and run 'kubectl get nodes' to verify 6 Ready nodes"
Write-Host "      - To stop again: .\cluster-stop.ps1"
