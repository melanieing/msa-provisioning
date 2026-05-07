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

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TerraformDir = Join-Path $ScriptDir "..\terraform"

Write-Host ""
Write-Host "[1/4] Terraform output 에서 EC2 ID 목록 가져오는 중..." -ForegroundColor Cyan

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

Write-Host "  region       : $Region"
Write-Host "  찾은 EC2 수  : $($InstanceIds.Count)"

Write-Host ""
Write-Host "[2/4] EC2 start 명령 전송 중..." -ForegroundColor Cyan

aws ec2 start-instances --region $Region --instance-ids $InstanceIds | Out-Null
Write-Host "  start 명령 전송 완료."

Write-Host ""
Write-Host "[3/4] 모든 인스턴스가 'running' 상태가 될 때까지 대기..." -ForegroundColor Cyan
Write-Host "       (약 30초~1분 소요)"

# AWS CLI 의 wait 명령은 인스턴스가 running 될 때까지 자동 대기
aws ec2 wait instance-running --region $Region --instance-ids $InstanceIds
Write-Host "  모든 인스턴스 running 상태 확인됨."

Write-Host ""
Write-Host "[4/4] inventory.ini 갱신을 위해 terraform apply 실행..." -ForegroundColor Cyan
Write-Host "       (bastion public IP 가 바뀌었을 수 있어서 inventory 재생성 필요)"
Write-Host ""

Push-Location $TerraformDir
try {
    # -auto-approve 로 자동 승인. EC2 만 변경되니 위험 없음.
    terraform apply -auto-approve
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "[완료] 클러스터가 다시 켜졌습니다." -ForegroundColor Green
Write-Host ""
Write-Host "       다음 단계:" -ForegroundColor Yellow
Write-Host "       - K8s 가 Ready 될 때까지 2~3분 더 기다리기 (kubelet/etcd 재기동)"
Write-Host "       - main-master SSH 후 'kubectl get nodes' 로 6 nodes Ready 확인"
Write-Host "       - 끄고 싶을 땐 .\cluster-stop.ps1"
