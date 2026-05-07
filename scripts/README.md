# scripts/

클러스터를 빠르게 띄우고 내리는 PowerShell 스크립트 모음.

---

## 🌅 일일 루틴 (이걸 가장 많이 씀)

```
아침 작업 시작
  ↓
.\cluster-bootstrap.ps1     ← terraform apply + ansible 까지 한 번에 (15~20분)
  ↓
[작업 / 데모 / 디버깅]
  ↓ (점심 같은 짧은 휴식이면)
.\cluster-stop.ps1          ← EC2 만 끄기 (1~2분, 빠름)
  ↓ (작업 재개)
.\cluster-start.ps1         ← EC2 다시 켜기 (1~2분)
  ↓
[작업 계속]
  ↓
저녁 작업 끝
  ↓
.\cluster-teardown.ps1      ← 전부 삭제, 비용 0 으로 만들기 (5분)
  ↓
다음날 아침으로 ↑ 반복
```

### 왜 이런 루틴?

| 휴식 길이 | 어떤 스크립트? | 이유 |
|---|---|---|
| **2시간 미만 (점심, 회의)** | stop / start | 다시 켜는 게 1~2분이라 빠름 |
| **저녁/주말/하루 이상** | teardown / bootstrap | 비용 0 — NAT/NLB 까지 다 삭제하니 시간당 0원 |

destroy/teardown 이 stop 보다 시간당 약 180원 더 절약. 13일에 약 4만원 차이.

---

## ⚙️ 처음 한 번만 (사전 준비)

### 1. AWS CLI

```powershell
# 자격증명 + 기본 region 입력 (ap-northeast-2)
aws configure
```

### 2. SSH 키 생성

```bash
# Git Bash 또는 WSL 에서
cd C:\Users\melan\ktcloudtechup\msa-provisioning
bash ssh-key-gen.bash
```

### 3. PowerShell 실행 정책 (PS1 파일 실행 허용)

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

### 4. Ansible 설치 (WSL 사용 권장)

Ansible 은 Linux 도구라 Windows 직접 설치는 어색함. WSL Ubuntu 에 설치하는 게 가장 편함.

```powershell
# WSL Ubuntu 들어가기 (처음이면 사용자 계정 만들라고 함)
wsl

# WSL 안에서 Ansible 설치
sudo apt update
sudo apt install -y ansible

# 설치 확인
ansible --version

# WSL 빠져나오기
exit
```

`cluster-bootstrap.ps1` 이 자동으로 WSL 안의 ansible 을 호출해줘서, 이거 한 번 깔아두면 끝.

> 💡 **WSL 처음이면**: PowerShell 에서 `wsl --install` 한 번만. (Microsoft 공식 가이드: https://learn.microsoft.com/ko-kr/windows/wsl/install)

### 5. AWS 콘솔에서 IAM Role 만들기

`ktcloud-cluster-node-role` 이라는 IAM Role 을 미리 만들어둬야 함.
정책: https://github.com/kubernetes-sigs/aws-load-balancer-controller/blob/main/docs/install/iam_policy.json
(상세는 `../README.md` 의 'NLB 등록용 IAM Role 사전 생성' 섹션 참고)

---

## 📜 스크립트별 상세

### `cluster-bootstrap.ps1` — 0 → 운영 가능 클러스터

```powershell
.\cluster-bootstrap.ps1
```

내부 동작 4단계:
1. **terraform init + apply** — VPC, EC2 8대, NAT, NLB, EFS, EBS 만듦 (~5분)
2. **30초 대기** — EC2 의 SSH 데몬이 시작될 시간
3. **ansible-playbook -i inventory.ini main.yaml** — WSL 안에서 자동 실행 (~10분)
   - swap off / 커널 모듈 / containerd
   - kubeadm init 으로 main-master 탄생
   - Calico CNI 설치
   - 나머지 master 2대 + worker 3대 join
   - Helm + AWS LBC + Argo CD 설치
4. **검증 안내** — main-master 접속 명령어 + Argo CD 비밀번호 추출법 출력

소요시간: **약 15~20분**. 이 동안 커피 ☕

### `cluster-teardown.ps1` — 운영 클러스터 → 0

```powershell
.\cluster-teardown.ps1
# 'yes' 입력해서 확인
```

내부 동작:
1. 사용자 확인 (`yes` 입력)
2. `terraform destroy -auto-approve` — 모든 AWS 리소스 영구 삭제

소요시간: **약 5분**.

⚠️ EBS/EFS 의 데이터도 삭제됨. 학습용이라 OK 지만 헷갈리지 말 것.

### `cluster-stop.ps1` / `cluster-start.ps1` — 짧은 휴식용

```powershell
.\cluster-stop.ps1     # EC2 만 끄기, 디스크 그대로 유지
.\cluster-start.ps1    # EC2 다시 켜기, 자동으로 inventory.ini 갱신
```

소요시간: **각 1~2분**. K8s 가 다시 Ready 되기까지 추가 2~3분.

⚠️ stop 중에도 NAT/NLB/EBS/EIP 비용은 계속 청구됨 (시간당 약 180원). 긴 휴식이면 teardown 이 더 쌈.

### `cluster-status.ps1` — 현재 상태 확인

```powershell
.\cluster-status.ps1
```

EC2 8대의 running/stopped 상태를 표로 출력. 비용 청구가 의심될 때 빠르게 확인용.

---

## 💰 비용 시나리오 비교 (13일 기준, 4h/일 작업)

| 운영 방식 | 13일 총비용 | 예산 66k | 비고 |
|-----------|------------|---------|------|
| 24h 계속 켜둠 | ~163,800원 | ❌ 2.5배 초과 | 사실상 불가능 |
| stop/start (4h 작업, 20h stop) | ~74,100원 | ❌ 살짝 초과 | NAT 가 stop 안 됨 |
| **teardown/bootstrap (4h 작업, 20h destroy)** | **~31,200원** | **✅ 절반 가량 여유** | 권장 |

teardown 이 압도적으로 쌈. 근데 매일 15~20분 다시 띄우는 시간 = 그게 트레이드오프.

---

## ❓ 자주 막히는 부분

### Q. `cluster-bootstrap.ps1` 이 ansible 단계에서 멈춤

원인 후보:
1. WSL 에 ansible 미설치 → 위의 '4. Ansible 설치' 따라가기
2. SSH 키 권한 문제 → WSL 안에서 `chmod 600 ~/.ssh/ktcloud-bastion-node-key`
3. IAM Role 미생성 → AWS 콘솔에서 `ktcloud-cluster-node-role` 만들었는지 확인

### Q. teardown 이 "VPC 가 사용 중" 에러로 실패

원인: 클러스터 안의 Argo CD/AWS LBC 가 만든 ALB/NLB 가 VPC 를 잡고 있음.
- AWS 콘솔 → EC2 → Load Balancers
- `kt-cloud-nlb` (Terraform 이 만든 거) 외의 Load Balancer 들을 수동 삭제
- 다시 `.\cluster-teardown.ps1` 실행

### Q. bootstrap 후 `kubectl get nodes` 가 NotReady 라고 나와

원인: kubelet/etcd 가 시동 중. 약 2~3분 더 기다리면 Ready 됨.
계속 NotReady 면 main-master 에서 `journalctl -u kubelet` 으로 로그 확인.

### Q. stop 했는데 비용이 계속 나감

당연한 거예요. NAT Gateway 와 NLB 와 EBS 와 EIP 는 stop 못 함 — 시간당 ~180원 계속.
0 원으로 만들려면 `cluster-teardown.ps1` 사용.

---

## 📂 스크립트 구조

```
scripts/
├── cluster-bootstrap.ps1   # 0 → 운영 클러스터 (15~20분)
├── cluster-teardown.ps1    # 운영 클러스터 → 0 (5분)
├── cluster-stop.ps1        # EC2 만 끄기 (1~2분)
├── cluster-start.ps1       # EC2 다시 켜기 + inventory 갱신 (1~2분)
├── cluster-status.ps1      # 현재 상태 표 출력
└── README.md               # 이 파일
```
