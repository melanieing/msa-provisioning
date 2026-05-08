# ─────────────────────────────────────────────────────────────────────────
# cluster-bootstrap.ps1
# ─────────────────────────────────────────────────────────────────────────
# AWS 인프라 + K8s 클러스터를 0 상태에서 완전히 처음부터 띄움.
# 자세한 동작 + 사전 조건은 scripts/README.md 참고.
# ─────────────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TerraformDir = Join-Path $ScriptDir "..\terraform"
$AnsibleDir = Join-Path $ScriptDir "..\ansible"

# WSL 에서 보는 ansible 디렉토리 경로 (예: /mnt/c/Users/melan/...)
# - Resolve-Path 로 '..' 정리
# - 'C:\foo\bar' → 'c/foo/bar' → '/mnt/c/foo/bar'
# (PS 5.1 호환 — script block 형식의 -replace 는 PS 7+ 전용이라 못 씀)
$AnsibleDirAbs = (Resolve-Path $AnsibleDir).Path
$AnsibleDirSlash = $AnsibleDirAbs -replace '\\', '/'
if ($AnsibleDirSlash -match '^([A-Z]):(.*)') {
    $AnsibleDirWsl = "/mnt/$($Matches[1].ToLower())$($Matches[2])"
} else {
    $AnsibleDirWsl = $AnsibleDirSlash
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Cluster bootstrap starting (~15-20 min total)" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# ─── Step 0/4: Pre-flight check ───────────────────────────────────
# 2026-05-09 + 2026-05-10 두 번 같은 함정에 빠짐 — terraform.tfvars 의
# ssh_*_key_path 가 Windows 절대경로 (C:/Users/.../) 면 terraform.exe 는 통과하지만
# WSL ansible 의 ProxyCommand 가 키 못 찾아 'Connection closed by UNKNOWN port 65535'
# 로 silently fail. ansible 단계 (~10분 후) 에서야 발견.
# → 시작 전에 즉시 차단. terraform 변수 default(~/.ssh/...) 가 양쪽 호환.
$TfvarsPath = Join-Path $TerraformDir "terraform.tfvars"
if (Test-Path $TfvarsPath) {
    $badPaths = Get-Content $TfvarsPath -ErrorAction SilentlyContinue |
                Where-Object { $_ -match '^\s*ssh_(private|public)_key_path\s*=\s*"[A-Za-z]:[/\\]' }
    if ($badPaths) {
        Write-Host ""
        Write-Host "============================================================" -ForegroundColor Red
        Write-Host " FATAL: terraform.tfvars 에 Windows 절대경로 ssh_*_key_path" -ForegroundColor Red
        Write-Host "============================================================" -ForegroundColor Red
        $badPaths | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
        Write-Host ""
        Write-Host "Windows 절대경로 (C:/Users/...) 는 terraform.exe 는 통과하지만" -ForegroundColor Yellow
        Write-Host "WSL ansible 이 키 못 찾아서 ~10분 후 ansible 단계에서 fail." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "[Fix] 해당 라인 제거 → default '~/.ssh/<ssh_key_name>' 사용" -ForegroundColor Green
        Write-Host "      (~ 는 Windows + WSL 양쪽 모두 안전하게 확장됨)" -ForegroundColor Green
        Write-Host "      ssh_private_key_path 변수는 제거됨 — ssh_key_name 으로 자동 derive." -ForegroundColor Green
        Write-Host ""
        throw "Aborted. Fix terraform.tfvars and re-run."
    }
    Write-Host "[0/4] Pre-flight: terraform.tfvars OK (no Windows abs path)." -ForegroundColor Green
}
Write-Host ""

# ─── Step 1/4: Terraform init + apply ─────────────────────────────
Write-Host "[1/4] terraform apply (creating AWS infra, ~5 min)..." -ForegroundColor Cyan
Push-Location $TerraformDir
try {
    Write-Host "      terraform init..."
    terraform init -upgrade | Out-Null

    Write-Host "      terraform apply -auto-approve..."
    terraform apply -auto-approve
    if ($LASTEXITCODE -ne 0) {
        throw "terraform apply failed."
    }
} finally {
    Pop-Location
}
Write-Host "      [OK] AWS infra ready." -ForegroundColor Green
Write-Host ""

# ─── Step 2/4: EC2 SSH 준비 대기 ──────────────────────────────────
Write-Host "[2/4] Waiting 30s for EC2 SSH daemons to be ready..." -ForegroundColor Cyan
Start-Sleep -Seconds 30
Write-Host "      [OK]" -ForegroundColor Green
Write-Host ""

# ─── Step 3/4: Ansible playbook 실행 ──────────────────────────────
Write-Host "[3/4] Running ansible-playbook (K8s bootstrap, ~10 min)..." -ForegroundColor Cyan
Write-Host ""

$NativeAnsible = Get-Command ansible-playbook -ErrorAction SilentlyContinue

if ($NativeAnsible) {
    Push-Location $AnsibleDir
    try {
        ansible-playbook -i inventory.ini main.yaml
    } finally {
        Pop-Location
    }
} else {
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
        Write-Host "[ERROR] ansible-playbook not found." -ForegroundColor Red
        Write-Host ""
        Write-Host "Install Ansible (one-time):" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Option 1 (recommended): WSL Ubuntu" -ForegroundColor Yellow
        Write-Host "    wsl"
        Write-Host "    sudo apt update; sudo apt install -y ansible"
        Write-Host "    exit"
        Write-Host ""
        Write-Host "  Option 2: pip" -ForegroundColor Yellow
        Write-Host "    pip install ansible"
        Write-Host ""
        Write-Host "  After install, re-run: .\cluster-bootstrap.ps1" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Or run ansible manually now:" -ForegroundColor Yellow
        Write-Host "    wsl"
        Write-Host "    cd $AnsibleDirWsl"
        Write-Host "    ansible-playbook -i inventory.ini main.yaml"
        Write-Host ""
        exit 1
    }

    Write-Host "      Running via WSL..." -ForegroundColor Cyan
    # PS 5.1 의 parser 가 string 안의 '&&' 도 chain operator 로 잘못 잡지 않도록
    # bash 명령을 변수에 미리 담아서 전달. bash 는 변수 안의 '&&' 를 정상 해석.
    $BashCmd = "cd '$AnsibleDirWsl' && ansible-playbook -i inventory.ini main.yaml"
    wsl -- bash -c $BashCmd
    if ($LASTEXITCODE -ne 0) {
        throw "ansible-playbook failed."
    }
}
Write-Host "      [OK] K8s cluster bootstrapped." -ForegroundColor Green
Write-Host ""

# ─── Step 4/4: 검증 안내 ──────────────────────────────────────────
Write-Host "[4/4] Verification info:" -ForegroundColor Cyan
Write-Host ""

Push-Location $TerraformDir
try {
    $ConnectCommand = terraform output -raw "main-master-node-connect-command"
} finally {
    Pop-Location
}

Write-Host "============================================================" -ForegroundColor Green
Write-Host " [DONE] Bootstrap complete." -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "SSH to main-master:" -ForegroundColor Yellow
Write-Host "    $ConnectCommand"
Write-Host ""
Write-Host "Then verify:" -ForegroundColor Yellow
Write-Host "    kubectl get nodes              # expect 6 Ready"
Write-Host "    kubectl get pods -A            # expect system pods Running"
Write-Host ""
Write-Host "Argo CD initial password:" -ForegroundColor Yellow
Write-Host "    kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=`"{.data.password}`" | base64 -d; echo"
Write-Host ""
Write-Host "When done: .\cluster-teardown.ps1 (or .\cluster-stop.ps1 for short break)" -ForegroundColor Yellow
Write-Host ""
