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
$AwsRegion = "ap-northeast-2"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host " [WARNING] Permanent cluster teardown" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "These AWS resources will be PERMANENTLY DELETED:" -ForegroundColor Yellow
Write-Host "  - VPC, Subnets x4, IGW, NAT x2, NLB, EIP x4"
Write-Host "  - EC2 8 instances (master 3 + worker 3 + bastion 2)"
Write-Host "  - EBS root volumes x8 + PVC dynamic EBS volumes (CNPG/Kafka/Redis/Loki etc)"
Write-Host "  - EFS x1 (all data lost), Security Groups x3, Instance Profile"
Write-Host "  - ECR repositories x4 (all images lost)"
Write-Host "  - KMS keys (ECR + EFS), GitHub OIDC provider, IAM Role for Actions"
Write-Host "  - VPC Endpoints (S3 gateway + KMS interface)"
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

# ─── Step 1/3: PVC cleanup (Issue S — orphan EBS 방지) ─────────────
# 진단 (2026-05-12): terraform destroy 가 EC2 만 죽이고 PVC 가 만든 dynamic EBS
# 는 cleanup 안 됨. K8s API 가 사라지면서 EBS-CSI driver 가 PVC 삭제 trigger 를
# 받지 못해 EBS 가 orphan 상태로 남아 비용 누적.
#
# 해법: terraform destroy 전에 kubectl 로 PVC 명시 삭제 → EBS-CSI driver 가
# AWS API 로 EBS volume 삭제 → 그 후 terraform destroy 가 EC2 만 죽임.
# cluster 가 이미 destroy 된 상태면 이 step 자동 skip.
Write-Host ""
Write-Host "[1/3] Pre-destroy PVC cleanup (orphan EBS 방지)..." -ForegroundColor Cyan

Push-Location $TerraformDir
try {
    $TfStateJson = terraform state list 2>&1
    $InstanceCount = ($TfStateJson | Select-String "aws_instance" | Measure-Object).Count
} finally {
    Pop-Location
}

if ($InstanceCount -gt 0) {
    Write-Host "      Cluster is running — running 'kubectl delete pvc --all -A'..." -ForegroundColor Cyan
    Push-Location $TerraformDir
    try {
        $ConnectCommand = terraform output -raw "main-master-node-connect-command" 2>$null
    } finally {
        Pop-Location
    }
    if ($ConnectCommand) {
        # ConnectCommand 끝에 remote 명령 추가 (single-quoted 로 escape 안전).
        # --wait=false: PV reclaim 비동기 trigger. --ignore-not-found=true: 일부 ns 빈 경우 OK.
        $RemoteCmd = "kubectl delete pvc --all -A --wait=false --ignore-not-found=true 2>&1 || true"
        $FullCmd = "$ConnectCommand `'$RemoteCmd`'"
        Write-Host "      $FullCmd" -ForegroundColor Gray
        Invoke-Expression $FullCmd
        Write-Host "      Waiting 60s for EBS-CSI driver to delete EBS volumes..." -ForegroundColor Cyan
        Start-Sleep -Seconds 60
    } else {
        Write-Host "      [WARN] terraform output failed — skipping PVC cleanup." -ForegroundColor Yellow
        Write-Host "             Safety net (Step 3) will catch any orphan EBS." -ForegroundColor Yellow
    }
} else {
    Write-Host "      No cluster running — skipping (no PVC to delete)." -ForegroundColor Gray
}
Write-Host ""

# ─── Step 2/3: terraform destroy ───────────────────────────────────
Write-Host "[2/3] Running terraform destroy (~5 min)..." -ForegroundColor Cyan
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

# ─── Step 3/3: Safety net — orphan EBS sweep (Issue S) ─────────────
# Step 1 이 실패했거나 cluster 가 처음부터 없었다면 PVC 가 만든 EBS 는 여전히 'available'.
# 이 step 이 마지막 안전망 — status=available 인 모든 EBS 일괄 삭제.
# (in-use 상태 EBS 는 어떤 EC2 에 attached — 우리는 EC2 다 destroy 후라 0개 expected.)
Write-Host "[3/3] Safety net — sweeping orphan EBS volumes..." -ForegroundColor Cyan
$Orphans = aws ec2 describe-volumes `
    --region $AwsRegion `
    --filters "Name=status,Values=available" `
    --query "Volumes[*].VolumeId" `
    --output text 2>$null

if ($Orphans) {
    $OrphanIds = $Orphans -split '\s' | Where-Object { $_ }
    Write-Host "      Found $($OrphanIds.Count) orphan volume(s) — deleting..." -ForegroundColor Yellow
    foreach ($vol in $OrphanIds) {
        Write-Host "        delete $vol"
        aws ec2 delete-volume --volume-id $vol --region $AwsRegion 2>&1 | Out-Null
    }
} else {
    Write-Host "      No orphan EBS volumes — clean." -ForegroundColor Green
}
Write-Host ""

Write-Host "============================================================" -ForegroundColor Green
Write-Host " [OK] All AWS resources deleted. Hourly cost = 0." -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "To bring it back: .\cluster-bootstrap.ps1" -ForegroundColor Yellow
Write-Host ""
