# ─────────────────────────────────────────────────────────────────────────
# cluster-bootstrap.ps1
# ─────────────────────────────────────────────────────────────────────────
# AWS 인프라 + K8s 클러스터를 0 상태에서 완전히 처음부터 띄움.
#
# 흐름:
#   1) terraform init + apply  → AWS 리소스 생성 (~5분)
#   2) EC2 SSH 준비 대기        → ~30초
#   3) ansible-playbook 실행    → K8s 부트스트랩 (~10분)
#   4) 검증 안내 출력
#
# 총 소요시간: 약 15~20분.
#
# 사용법:
#   PowerShell 에서:
#     cd C:\Users\melan\ktcloudtechup\msa-provisioning\scripts
#     .\cluster-bootstrap.ps1
#
# 사전 조건:
#   - AWS CLI 설치 + 'aws configure' 완료
#   - WSL 에 ansible 설치됨 (자세한 설치는 scripts/README.md 참고)
#   - ssh-key-gen.bash 한 번 실행해서 ~/.ssh/ktcloud-bastion-node-key 가 있음
#   - AWS 콘솔에서 'ktcloud-cluster-node-role' IAM Role 미리 생성됨
# ─────────────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TerraformDir = Join-Path $ScriptDir "..\terraform"
$AnsibleDir = Join-Path $ScriptDir "..\ansible"

# WSL 에서 보는 ansible 디렉토리 경로 (예: /mnt/c/Users/melan/...)
$AnsibleDirWsl = ($AnsibleDir -replace '^([A-Z]):', '/mnt/$1' -replace '\\', '/').ToLower() -replace '/mnt/c:', '/mnt/c'
# 위 변환의 'c:' 처리가 살짝 이상해서 안전하게 다시 깨끗히 변환:
$AnsibleDirWsl = $AnsibleDir -replace '\\', '/' -replace '^([A-Z]):', { '/mnt/' + $args[0].Groups[1].Value.ToLower() }

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host " 클러스터 부트스트랩 시작 (전체 약 15~20분 소요)" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

# ─── Step 1/4: Terraform init + apply ─────────────────────────────
Write-Host "[1/4] Terraform 으로 AWS 인프라 생성 중... (~5분)" -ForegroundColor Cyan
Push-Location $TerraformDir
try {
    Write-Host "      terraform init..."
    terraform init -upgrade | Out-Null

    Write-Host "      terraform apply -auto-approve..."
    terraform apply -auto-approve
    if ($LASTEXITCODE -ne 0) {
        throw "terraform apply 실패. 위 에러 메시지 확인하세요."
    }
} finally {
    Pop-Location
}
Write-Host "      [OK] AWS 인프라 생성 완료." -ForegroundColor Green
Write-Host ""

# ─── Step 2/4: EC2 SSH 준비 대기 ──────────────────────────────────
Write-Host "[2/4] EC2 SSH 준비될 때까지 30초 대기..." -ForegroundColor Cyan
Write-Host "      (terraform 은 'EC2 생성됨' 확인까지만 보장. SSH 데몬 가동까지 살짝 더 필요.)"
Start-Sleep -Seconds 30
Write-Host "      [OK] 대기 완료." -ForegroundColor Green
Write-Host ""

# ─── Step 3/4: Ansible playbook 실행 ──────────────────────────────
Write-Host "[3/4] Ansible 로 K8s 부트스트랩 중... (~10분)" -ForegroundColor Cyan
Write-Host "      ansible-playbook -i inventory.ini main.yaml"
Write-Host ""

# ansible-playbook 을 어떻게 실행할지 결정:
#   1) Windows PATH 에 있으면 그대로 실행 (드물지만 가능)
#   2) WSL 에서 실행 (가장 흔한 케이스)
#   3) 둘 다 없으면 에러 + 안내
$NativeAnsible = Get-Command ansible-playbook -ErrorAction SilentlyContinue

if ($NativeAnsible) {
    Push-Location $AnsibleDir
    try {
        ansible-playbook -i inventory.ini main.yaml
    } finally {
        Pop-Location
    }
} else {
    # WSL 에서 ansible-playbook 가 있는지 확인
    $WslHasAnsible = $false
    try {
        $check = wsl -- bash -c "command -v ansible-playbook" 2>$null
        if ($LASTEXITCODE -eq 0 -and $check) {
            $WslHasAnsible = $true
        }
    } catch {
        $WslHasAnsible = $false
    }

    if (-not $WslHasAnsible) {
        Write-Host ""
        Write-Host "[ERROR] ansible-playbook 을 찾을 수 없어요." -ForegroundColor Red
        Write-Host ""
        Write-Host "다음 중 하나를 따라 Ansible 을 설치해주세요:" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  방법 1: WSL Ubuntu 에서 (가장 권장)" -ForegroundColor Yellow
        Write-Host "    wsl"
        Write-Host "    sudo apt update && sudo apt install -y ansible"
        Write-Host "    exit"
        Write-Host ""
        Write-Host "  방법 2: pip 로 (Windows Python 직접)" -ForegroundColor Yellow
        Write-Host "    pip install ansible"
        Write-Host ""
        Write-Host "  설치 후 다시 .\cluster-bootstrap.ps1 실행." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "또는 지금 수동으로 ansible 부분만 따로 실행하시려면:" -ForegroundColor Yellow
        Write-Host "    wsl"
        Write-Host "    cd $AnsibleDirWsl"
        Write-Host "    ansible-playbook -i inventory.ini main.yaml"
        Write-Host ""
        exit 1
    }

    Write-Host "      WSL 에서 ansible-playbook 실행..." -ForegroundColor Cyan
    # WSL 의 ansible-playbook 호출. WSL 안에서는 /mnt/c/... 경로 사용.
    wsl -- bash -c "cd '$AnsibleDirWsl' && ansible-playbook -i inventory.ini main.yaml"
    if ($LASTEXITCODE -ne 0) {
        throw "ansible-playbook 실행 실패. 위 에러 메시지 확인하세요."
    }
}
Write-Host "      [OK] K8s 부트스트랩 완료." -ForegroundColor Green
Write-Host ""

# ─── Step 4/4: 검증 안내 ──────────────────────────────────────────
Write-Host "[4/4] 검증 안내" -ForegroundColor Cyan
Write-Host ""

Push-Location $TerraformDir
try {
    $ConnectCommand = terraform output -raw "main-master-node-connect-command"
} finally {
    Pop-Location
}

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host " ✅ 부트스트랩 완료" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host ""
Write-Host "📋 main-master 접속 명령:" -ForegroundColor Yellow
Write-Host "    $ConnectCommand"
Write-Host ""
Write-Host "📋 접속 후 검증:" -ForegroundColor Yellow
Write-Host "    kubectl get nodes              # → 6 nodes Ready 확인"
Write-Host "    kubectl get pods -A            # → 모든 시스템 pod Running"
Write-Host ""
Write-Host "📋 Argo CD 초기 비밀번호 확인:" -ForegroundColor Yellow
Write-Host "    kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=`"{.data.password}`" | base64 -d; echo"
Write-Host ""
Write-Host "💸 작업 끝나면: .\cluster-teardown.ps1 (또는 잠깐 멈춤이면 .\cluster-stop.ps1)" -ForegroundColor Yellow
Write-Host ""
