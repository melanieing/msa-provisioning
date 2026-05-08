# Market Service MSA — 백로그 & 진행 상황

> **마지막 갱신**: 2026-05-10
> 단일 진실 원천(SSOT). 작업 시작/완료 시 여기 갱신.

---

## 📊 스냅샷

| 항목 | 값 |
|---|---|
| **마감일** | 2026-05-20 |
| **남은 일수** | 11일 |
| **현재 위치** | 어제 fix 한 3개 sync 이슈 모두 cluster-bootstrap 으로 검증 완료 ✅. 새 이슈 2개 발견: D (Strimzi 1.0 v1beta2 제거), E (ECR pull 인증) |
| **진행률** | Phase A 100%, **Phase B 92%** (어제 3개 검증, 새 D/E 잡는 중), Phase C 0%, Phase D 75% |
| **AWS 비용 사용량** | 클러스터 가동 중 (시간당 ~553 KRW). 작업 끝나면 destroy |

### 다음 우선순위 (순서대로)

1. **🟡 Issue D fix (in progress)** — `_kafka/*.yaml` 의 `kafka.strimzi.io/v1beta2` → `v1` 으로. push 후 ArgoCD 가 재 sync.
2. **🔴 Issue E — ECR pull 인증** — K8s 1.27+ 부터 kubelet 내장 ECR auth 제거됐는데 `ecr-credential-provider` 플러그인 미설치. 해결 옵션: (a) Ansible 로 노드별 플러그인 설치 (정공법, 별도 playbook), (b) imagePullSecret 수동 (12h 만료, stopgap), (c) ECR 토큰 자동 갱신 CronJob.
3. **마이크로서비스 Pod Healthy 확인** — D + E fix 후 user-api-gateway / product / order / inventory 4개 Pod 가 실제 Running 인지.
4. **[Phase C-1]** JWT secret + DB 비밀번호 K8s Secret 으로 옮기기.

### ✅ 오늘 검증 완료 (어제 fix 의 결과)

- **이슈 A — platform-of-apps 분리**: 새 부모 3개 (operators-app/data-app/observability-app) 모두 Healthy/Synced. recurse:false 가 raw CR 직접 적용 차단함 — 의도대로 동작.
- **이슈 B — apps Namespace whitelist**: 4 microservice Application 모두 Synced (Namespace 생성됨). 더 이상 "resource :Namespace is not permitted" 에러 없음.
- **이슈 C — Helm 차트 group/version empty**: 4 microservice 차트 모두 manifest 정상 적용. 더 이상 "groupVersion shouldn't be empty" 에러 없음.

### 🆕 오늘 부트스트랩 검증 중 발견된 새 이슈 2개

- **이슈 D**: `kafka-cluster` Application 에서 `The Kubernetes API could not find version "v1beta2" of kafka.strimzi.io/Kafka. Version "v1" is installed`. 원인: Strimzi 0.45 → 1.0.0 업그레이드 (어제) 시 메이저 변경 — `v1beta2` 제거. 우리 yaml 8곳 (kafka-cluster.yaml ×3, topics.yaml ×5) 갱신 필요. **fix 적용 완료, push 대기**.
- **이슈 E**: 마이크로서비스 Pod 들이 `Failed to pull image: ... no basic auth credentials`. 원인: K8s 1.27+ 부터 kubelet 내장 ECR 자동 인증 제거됨. K8s 1.35 는 `ecr-credential-provider` 플러그인이 노드별 설치돼야 함. IAM Role 의 ECR pull 권한은 이미 있지만 kubelet 이 그걸 활용 못함. **다음 세션 핵심 작업** — Ansible playbook 작성 후보. 면접 답변 가치 큼.

### ✅ 오늘 fix 완료 (3건)

- **이슈 A — platform-of-apps 분리**: `bootstrap/platform-of-apps.yaml` 삭제, 대신 `platform-operators-app.yaml`(-50) / `platform-data-app.yaml`(-40) / `platform-observability-app.yaml`(-30) 3개 신규. 핵심: **`recurse: false`** 로 부모가 raw CR (`_postgres/_kafka/_redis`) 직접 apply 못 하게 차단. 자식 Application 만 sync 하고, 자식이 자기 서브폴더의 CR 을 sync 하므로 그때엔 CRD 이미 등록된 상태.
- **이슈 B — apps AppProject Namespace whitelist**: `projects/apps-project.yaml` 의 `clusterResourceWhitelist: []` → `[{group: "", kind: Namespace}]`. ApplicationSet 의 `CreateNamespace=true` 가 `user-api-gateway` 등 namespace 만들 수 있음. CRD/ClusterRole 은 여전히 차단.
- **이슈 C — Helm 차트 serviceaccount.yaml 의 `{{- if .. -}}` whitespace trim 버그**: `-}}` 가 다음 줄 newline 까지 먹어서 코멘트 라인 (`# ─────`) 과 `apiVersion: v1` 이 한 줄로 붙어버려 `apiVersion` 이 코멘트 안으로 들어감 → manifest 의 group/version 이 비게 됨. 4개 차트 (`user-api-gateway` / `product-service` / `order-service` / `inventory-service`) 모두 `-}}` → `}}` 로 수정. 4개 모두 helm lint + render 통과.

### 🚨 위험 / 차단 요소

- ✅ **2026-05-08 발견**: 첫 destroy 시 ECR repo 가 이미지 있어서 `RepositoryNotEmptyException` 으로 막힘. **fix 적용 완료** — `modules/registry/main.tf` 에 `force_delete = true` 추가.
- ✅ **2026-05-09 발견**: `cluster-bootstrap.ps1` 의 WSL path 변환에 PS 7+ 전용 문법(script block in -replace) 사용해서 PS 5.1 에서 실패. **fix 적용 완료** — Resolve-Path + manual regex replace 로 교체.
- ✅ **2026-05-09 발견**: `terraform.tfvars` 의 `ssh_private_key_path` 가 Windows 절대경로(`C:/...`)로 override 되어 inventory.ini 에 박혀 WSL ansible 의 ProxyCommand 가 키를 못 찾음. **fix 절차** — tfvars 의 그 라인 제거 → default(`~/.ssh/...`) 사용 → ssh 가 자동으로 home 풀음. 즉시 처리는 sed 로 inventory.ini 패치.
- ✅ **2026-05-09 발견**: inventory.tftpl 의 group vars 가 [all:vars] 의 `ansible_ssh_common_args` 를 override 해서 outer SSH(private 노드로) 의 `StrictHostKeyChecking=no` 가 적용 안 됨 → fingerprint 프롬프트. **fix 적용 완료** — group vars 의 args 에 outer + inner 둘 다 명시. 즉시 우회는 `ANSIBLE_HOST_KEY_CHECKING=False` env.
- ✅ **2026-05-10 fix**: `platform-of-apps` 단일 Application 을 3개로 분리 (operators/data/observability). 핵심은 `recurse: false` — 옛 recurse:true 가 `_postgres/_kafka/_redis` 의 raw CR 까지 부모가 직접 apply 시도해서 CRD 인식 실패였음. 이제 부모는 Application yaml 만 apply, 자식이 자기 CR 처리.
- ✅ **2026-05-10 fix**: `apps-project.yaml` 의 `clusterResourceWhitelist` 에 `Namespace` 추가. ApplicationSet 의 CreateNamespace=true 가 동작.
- ✅ **2026-05-10 fix**: 4개 차트 `serviceaccount.yaml` 의 `{{- if .. -}}` 의 trailing `-}}` 가 newline 을 먹어서 `apiVersion: v1` 이 코멘트 라인 끝에 붙음 → `-}}` 를 `}}` 로 변경. 4개 차트 모두 helm lint + render 통과.
- ✅ **2026-05-09 발견**: `kubeadm-config.yaml.j2` 의 `certSANs` 가 root level 에 있어 K8s 1.35 의 v1beta3 검증 실패 (`block sequence entries are not allowed in this context`). **fix 적용 완료** — `apiServer.certSANs` 아래로 이동 + indent 2 spaces 통일. 원작자가 K8s 1.30 에서 만든 거라 lenient 하게 통과했지만 1.35 에선 엄격.
- ✅ **2026-05-09 해결**: 첫 클러스터 부트스트랩 100% 성공. PDF 5.5.1 의 DR 시나리오 4단계 검증 완료.
- ✅ **2026-05-08 발견**: 사용자 첫 `terraform plan` 시 사전 준비 누락 발견 → SSH 키 + IAM Role 수동 생성 가이드 안내. 후속: IAM Role 도 Terraform 자동화 (아래 추가)
- Helm 차트 버전들이 cutoff 이후이긴 하나 실제 클러스터에서 깨질 가능성

---

## ✅ 완료 (역순, 최근 → 옛날)

### 2026-05-10 (오후 — 부트스트랩 검증)
- ✅ **🎉 어제 fix 한 3개 sync 이슈 cluster-bootstrap 으로 검증 완료** — A (platform-of-apps 분리 + recurse:false), B (apps Namespace whitelist), C (Helm chart group/version empty) 모두 의도대로 동작. ArgoCD UI 에서 platform-operators-app / platform-data-app / platform-observability-app 모두 Healthy/Synced. 4 microservice Application 모두 Synced (Pod 단계 진행 중).
- 🐛 **새 이슈 2개 발견** (어제와 무관):
  - **이슈 D — Strimzi 1.0.0 의 v1beta2 제거**: `kafka.strimzi.io/v1beta2` 가 더 이상 cluster 에 등록 안 됨 (메이저 업그레이드 영향). `_kafka/kafka-cluster.yaml` (3곳) + `_kafka/topics.yaml` (5곳) 의 apiVersion 을 `v1` 로 변경. **fix 완료, push 후 ArgoCD 재sync 대기**.
  - **이슈 E — ECR pull "no basic auth credentials"**: K8s 1.27 부터 kubelet 내장 ECR 인증 제거. K8s 1.35 는 `ecr-credential-provider` 플러그인 필요. Ansible playbook 작성 (다음 세션) 또는 stopgap 으로 imagePullSecret. **미fix**.
- 부트스트랩 도중 발견된 ssh-agent / Windows 경로 이슈 (어제 fix 한 것의 재발) → terraform.tfvars 에 다시 들어간 ssh_private_key_path 라인 영구 제거. 이번엔 두 번째라 영구 fix 가 필요한 듯 (terraform.tfvars.example 나 README 안내 갱신 검토).
- 두 번째 terraform apply 시 15+15 churn 발생 (EC2/EIP 일부 재생성). 원인 미확인 — 비용 영향 미미. 다음 세션에서 추적 가능.

### 2026-05-10 (오전)
- ✅ **🐛 어제 발견된 3개 sync 이슈 모두 fix** (재부트스트랩 검증 대기):
  - **이슈 A — platform-of-apps 분리**: `bootstrap/platform-of-apps.yaml` 삭제 + 3개 신규 (`platform-operators-app.yaml` / `platform-data-app.yaml` / `platform-observability-app.yaml`). 각자 자기 서브폴더만 watch + **`recurse: false`** (옛 recurse:true 가 `_postgres/_kafka/_redis` raw CR 직접 apply 시도해서 CRD 인식 실패). 자식 Application 들이 자기 CR 처리하도록 위임. 부모 wave 는 -50 / -40 / -30 으로 dependency 정의. 관련 파일 코멘트 / README 도 같이 갱신 (`msa-argocd-manifest/README.md`, `platform/README.md`, `cnpg-operator.yaml`, `apps-appset.yaml`, `STACK.md`, `argocd-setup.yaml`).
  - **이슈 B — apps AppProject Namespace 허용**: `projects/apps-project.yaml` 의 `clusterResourceWhitelist: []` → `[{group: "", kind: Namespace}]`. CRD/ClusterRole 은 여전히 차단해서 마이크로서비스 권한 안전장치 유지.
  - **이슈 C — Helm 차트 group/version empty 버그**: 4개 차트의 `templates/serviceaccount.yaml` 에서 `{{- if .Values.serviceAccount.create -}}` 의 trailing `-}}` 가 다음 줄 newline 을 먹어서 코멘트 라인 (`# ─────`) 과 `apiVersion: v1` 이 한 줄로 붙음 → `apiVersion` 이 `#` 코멘트 안으로 들어가 사라짐 → manifest 의 group/version 비어 ArgoCD discovery 실패. `-}}` → `}}` (closing dash 만 제거). 4개 차트 (`user-api-gateway` / `product-service` / `order-service` / `inventory-service`) 모두 helm lint + render 검증 통과 (4개 manifest 의 apiVersion 모두 자기 줄에 정상).

### 2026-05-09
- ✅ **🎉🎉 첫 클러스터 부트스트랩 100% 성공** — `ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook` 로 11개 playbook 모두 완주. 6 노드 모두 `failed=0 unreachable=0`. main-master 의 `ok=50 changed=26` 은 kubeadm init + Calico + Helm + AWS LBC + Argo CD 까지 다 완료. PDF 5.5.1 의 4단계 부트스트랩 (Terraform → Ansible → kubectl apply argocd → root sync) 검증 완료.
- 부트스트랩 도중 발견된 4개 이슈 모두 fix (PowerShell path conversion / private_key_path 절대경로 / SSH host key checking / kubeadm-config v1beta3 certSANs) — 다음번부터 자동 처리.

### 2026-05-08
- ✅ **🐛 ECR force_delete fix** — 첫 destroy 시 발견된 `RepositoryNotEmptyException` 의 영구 해결책. `modules/registry/main.tf` 에 `force_delete = true` 추가. 다음 destroy 부터 이미지 자동 정리.
- ✅ **B-2d/e/f 3개 backend 서비스 Helm 차트 + B-2c 리팩터** — product-service / order-service / inventory-service 차트 작성. ports list 패턴 도입으로 4개 차트가 동일 templates (deployment/service/configmap/serviceaccount/_helpers) 공유. backend 들은 듀얼 포트(HTTP + gRPC), gateway 는 단일. 각각 PG/Kafka/Redis 연결 env. 4개 차트 helm lint 모두 통과.
- ✅ **B-2c user-api-gateway Helm 차트 작성** — Chart.yaml + values.yaml + 5 templates (deployment, service, configmap, serviceaccount, _helpers.tpl). non-root securityContext + actuator liveness/readiness probes + ECR image. helm lint + template render 통과.
- ✅ **Phase B ID 체계 통일** — B1~B8 → B-1a~g, B6a~e → B-2c~g (sub-phase 일관성).
- ✅ **🎉 D-1 첫 빌드 성공 — ECR 에 4개 이미지 push 완료** (4분 11초). registry: `601766312629.dkr.ecr.ap-northeast-2.amazonaws.com`. 각 서비스마다 `<git_sha> + latest` 두 태그.
- ✅ **D1-d GitHub Actions workflow 작성** — `.github/workflows/build-and-push.yml`. 단일 yaml + **matrix 전략** (4개 서비스 병렬 빌드) + **OIDC 페더레이션** (GitHub Secrets 미사용) + `aws-actions/amazon-ecr-login` + `docker/build-push-action` (GHA layer cache, 2회차 빌드 단축). 두 태그 (`git sha` + `latest`) 동시 push.
- ✅ **5개 PowerShell 스크립트 영어 메시지로 재작성** — 사용자 PowerShell 의 한글 인코딩 깨짐 fix. `[Console]::OutputEncoding = UTF8` 도 보강.
- ✅ **🚀 첫 terraform apply 성공** — 63개 AWS 리소스 생성 완료. VPC + EC2 ×8 + NLB + EFS + EBS + ECR ×4 + KMS + GitHub OIDC + IAM Role. Outputs 정상 출력 (bastion IP, master IP 등). AWS 청구 시작.
- ✅ **사용자 환경 사전 준비 완료** — SSH 키 (Git Bash/WSL→Windows 복사) + IAM Role (`ktcloud-cluster-node-role` AWS CLI 로 생성 + LBC 정책 attach).
- ✅ **D1-a/b/c Terraform 인프라 추가 (ECR + OIDC + IAM)** — `modules/registry` (ECR ×4 + KMS 키 + lifecycle policy) + `modules/github-oidc` (OIDC provider + GitHub Actions assume role + ECR push policy with sub condition). compute 모듈의 노드 Role 에 `AmazonEC2ContainerRegistryReadOnly` attach. terraform validate 통과.
- ✅ **B-2b 4개 서비스 Dockerfile + .dockerignore** — 멀티스테이지 (jdk build → layered extract → jre runtime), Spring Boot layered jar 활용 (캐싱 효율), non-root user (보안), HEALTHCHECK (actuator). 4개 service 모듈에 `bootJar` 활성 + root 의 라이브러리 default 비활성을 화이트리스트 기반으로 정리. 실 `docker build` 검증은 사용자 로컬 Docker 미설치라 D-1 CI 에서.
- ✅ **A9 Spring Boot 3.3.0 → 3.5.14 업그레이드** — `./gradlew assemble` 14개 모듈 모두 통과. 부가 변경:
  - Spring Cloud Gateway 4.1.9 → 4.3.0 (Spring Boot 3.5 짝)
  - user-api-gateway 의 webflux 하드코딩 버전 제거 (Boot plugin 자동 매니지)
  - root 의 Spring Boot plugin → `apply false` (멀티모듈 표준 패턴)
  - subprojects 의 라이브러리 모듈 bootJar 자동 비활성 (application 모듈에서만 override)
  - **Gradle wrapper jar/properties 누락 fix** (Spring Initializr 에서 추출. Gradle 8.14.4)
- ✅ **BACKLOG.md 작성** — 진행 상황 SSOT
- ✅ **STACK.md 작성** — 전체 기술 스택 + 버전 한 페이지 카탈로그
- ✅ **Tech stack 전체 업데이트** — 2026-05 기준 최신 안정 버전 정합성 (Strimzi 0.45→1.0, K8s 1.30→1.35, Calico 3.27→3.32, Helm 3.14→3.20.2 외)
- ✅ **Phase B-1: platform/data 채움** — CNPG Cluster ×5 + Strimzi Kafka + Redis Cluster + 5 토픽
- ✅ **Terraform module화** — flat .tf → 5개 모듈 (network/security/compute/loadbalancer/storage)

### 2026-05-07
- ✅ **EC2 비용 절감 스크립트 5종**: bootstrap / teardown / stop / start / status (PowerShell)
- ✅ **Ansible WSL 자동 호출** + inventory.tftpl 의 ProxyCommand 자동화 친화 (StrictHostKeyChecking=no)
- ✅ **Terraform 변수화** — `provider.tf` + `variables.tf` 13개 변수 + `terraform.tfvars.example`
- ✅ **모든 소스에 친절한 한글 주석** + 일본어 → 한국어 번역
- ✅ **Argo CD 매니페스트 리포 골격 생성** (`msa-argocd-manifest`) — bootstrap + projects + platform 구조
- ✅ **Argo CD root Application URL 본인 소유로 교체** (kanei0415 → melanieing)
- ✅ **claude/amazing-curran-2040f2 worktree** 에서 CLAUDE.md 작성 (작업 원칙)
- ✅ **PDF 분석 + 코드 분석 + 실현가능성 평가**

---

## 📋 Phase A — 기반 작업 (대부분 완료, 일부 잔여)

| ID | 항목 | 상태 | 비고 |
|---|---|---|---|
| A1 | 거버넌스 (BACKLOG / Project tracking) | 🟡 진행 중 | 이 파일이 그것 |
| A2 | Argo CD 매니페스트 리포 생성 | ✅ 완료 | melanieing/msa-argocd-manifest |
| A3 | Terraform variables.tf 변수화 | ✅ 완료 | 13개 변수, zero drift |
| A4 | Terraform S3 backend + DynamoDB lock | ⏳ 미진행 | 팀 협업 / DR 신뢰성. 1인 학습 프로젝트라 우선순위 ↓ |
| A5 | KMS CMK + EBS/EFS/S3 SSE 암호화 | ⏳ 미진행 | PDF 5.3절 명시. **Phase D 보안 작업 시 같이** |
| A6 | VPC Endpoint (S3, KMS) | ⏳ 미진행 | PDF 5.1절. 이그레스 비용 절감 |
| A7 | EC2 stop/start/bootstrap/teardown 스크립트 | ✅ 완료 | 5종 PowerShell 스크립트 |
| A8 | Ansible argocd_namespace 변수 + URL fix | ✅ 완료 | 외부 레포 수정으로 사용자가 진행 |
| A9 | **Spring Boot 3.3.0 → 3.5.14 업그레이드** | ✅ **완료** (2026-05-08) | + Cloud Gateway 4.1.9→4.3.0, multi-module bootJar 설정 정리, gradle wrapper 누락 fix |
| A10 | **4개 서비스 Dockerfile** + 멀티스테이지 빌드 | ✅ 완료 (2026-05-08) | layered jar + non-root + healthcheck. notification-service 는 모듈 자체 미존재라 제외. |
| A+ | NAT Gateway 1개로 줄이기 (선택) | ⏳ 검토 | 시간당 60원 절감. HA 손해. 4h/일 운영 시 사실상 불필요 |
| A++ | `ktcloud-cluster-node-role` IAM Role 도 Terraform 자동화 | ⏳ 검토 (낮은 우선순위) | 현재는 사용자가 콘솔/CLI 로 수동 생성. 자동화하면 destroy/bootstrap 더 깨끗. LBC IAM 정책 JSON 인라인 또는 data 로 fetch. |

---

## 📋 Phase B — GitOps + 매니페스트

### B-1: 매니페스트 리포 + 플랫폼 (완료)

| ID | 항목 | 상태 | 비고 |
|---|---|---|---|
| B-1a | 매니페스트 리포 폴더 구조 | ✅ 완료 | bootstrap/projects/platform/applications |
| B-1b | App-of-Apps Root + Sync Wave | ✅ 완료 | 표준 정책 + finalizer 설정 |
| B-1c | CNPG Helm + 5 PostgreSQL Cluster | ✅ 완료 | namespace `data` + Cluster CRD ×5 |
| B-1d | Strimzi Kafka KRaft 3-broker | ✅ 완료 | 1.0.0 + Kafka 4.2.0 + KafkaTopic ×5 |
| B-1e | Redis Operator + RedisCluster | ✅ 완료 | 3 master + 3 replica + 평문 Secret (학습용) |
| B-1f | ApplicationSet (Git Generator) | ✅ 완료 | charts/services/* watch (아직 빈 상태) |
| B-1g | Sync Policy 표준화 | ✅ 완료 | prune/selfHeal/CreateNamespace/ServerSideApply |

### B-2: 마이크로서비스 차트화 (지금)

| ID | 항목 | 상태 | 위치 |
|---|---|---|---|
| B-2a | bootJar 활성화 패턴 (root + service 4개 build.gradle.kts) | ✅ 완료 (2026-05-08) | A9 와 함께 진행됨 |
| B-2b | 4개 서비스 Dockerfile + .dockerignore | ✅ 완료 (2026-05-08) | 멀티스테이지 + layered jar + non-root + healthcheck |
| B-2c | **user-api-gateway Helm 차트** | ✅ **완료** (2026-05-08) | Chart.yaml + values.yaml + 5 templates. ports list 패턴으로 리팩터 (4개 차트가 같은 templates 공유) |
| B-2d | **product-service Helm 차트** | ✅ **완료** (2026-05-08) | HTTP(8001) + gRPC(9001) 듀얼 포트. CNPG product-db 연결 |
| B-2e | **order-service Helm 차트** | ✅ **완료** (2026-05-08) | HTTP(8002) + gRPC(9002). CNPG order-db + Strimzi Kafka |
| B-2f | **inventory-service Helm 차트** | ✅ **완료** (2026-05-08) | HTTP(8003) + gRPC(9003). CNPG inventory-db + Kafka + Redis Cluster |
| B-2g | notification-service Helm 차트 | ⏳ | `charts/services/notification-service/` (서비스 자체 미구현, 후순위) |

각 차트 골격: Chart.yaml + values.yaml + templates/{deployment,service,configmap,_helpers.tpl}

---

## 📋 Phase C — 백엔드 보강 (시작 전)

| ID | 항목 | 상태 | 영향 | 우선순위 |
|---|---|---|---|---|
| C1 | JWT 인증 필터 (게이트웨이) | ⏳ | 보안 — 현재 permitAll | Must |
| C2 | Rate Limit 필터 (Token Bucket) | ⏳ | 보안 / 안정성 | Must |
| C3 | Resilience4j Circuit Breaker | ⏳ | 가용성 (PDF 핵심) | Must |
| C4 | Outbox Poller (`@Scheduled`) | ⏳ | 메시지 At-least-once 보증 | Must |
| C5 | notification-service 최소 구현 | ⏳ | 5번째 서비스 | Must (descope 시 단일 채널) |
| C6 | IdempotentEventAspect 구현 | ⏳ | 중복 메시지 방지 | Should |
| C7 | Saga 보상 로직 1개 (재고부족→주문취소) | ⏳ | 분산 트랜잭션 | Should |
| C8 | JWT secret 등 → K8s Secret | ⏳ | 보안 | Must |

---

## 📋 Phase D — CI / 관측성 / 검증 (시작 전)

| ID | 항목 | 상태 | 우선순위 |
|---|---|---|---|
| D1 | GitHub Actions CI (빌드 + 테스트 + 이미지 push + tag bump) | ✅ **핵심 완료** (2026-05-08) | 첫 push 성공: 4 services × `(git_sha + latest)` tags pushed to ECR in **4m 11s**. tag bump 만 후속 |
| D1-a | Terraform: modules/registry (ECR ×4 + KMS + lifecycle) | ✅ 완료 (2026-05-08) | KMS 키 + scan_on_push + lifecycle (untagged 30, tagged 50) |
| D1-b | Terraform: modules/github-oidc (OIDC provider + IAM Role) | ✅ 완료 (2026-05-08) | sub condition 으로 melanieing/msa-spring-boot 의 main + claude/* 만 허용 |
| D1-c | EC2 노드 Role 에 ECR Pull 권한 attach | ✅ 완료 (2026-05-08) | AmazonEC2ContainerRegistryReadOnly 정책 attach |
| D1-d | GitHub Actions workflow (matrix 전략, 4개 서비스) | ✅ **완료** (2026-05-08) | 단일 yaml + matrix + OIDC + ECR push + GHA layer cache |
| D1-e | 매니페스트 리포 image tag 자동 bump | ⏳ 후속 | 첫 push 검증 후 진행 |
| D2 | OpenTelemetry SDK 5개 서비스 통합 | ⏳ | Must |
| D3 | Prometheus + Loki + Grafana values 채움 | ⏳ | Must |
| D4 | Grafana 대시보드 1~2개 (latency, Kafka lag) | ⏳ | Must |
| D5 | Tempo (분산 트레이싱) | ⏳ | Should |
| D6 | Mimir (장기 메트릭) | ⏳ | Could |
| D7 | S3 + CloudFront + ACM 정적 placeholder | ⏳ | Should |
| D8 | Postman + Newman E2E 시나리오 | ⏳ | Must |
| D9 | Testcontainers 통합 테스트 1개 | ⏳ | Should |
| D10 | Chaos 데모 (Pod 강제 종료) | ⏳ | Should |
| D11 | Trivy 컨테이너 스캔 | ⏳ | Should |
| D12 | 발표 자료 + README 갱신 + 데모 시나리오 | ⏳ | Must |

---

## ❌ Won't (이번 스프린트 제외)

| 항목 | 이유 |
|---|---|
| Istio Service Mesh | PDF 의 "심화" — 학습 곡선 ↑, 시간 부족 |
| AlertManager → PagerDuty | 운영 단계가 아님 |
| React 풀앱 프론트엔드 | DevOps 포트폴리오 우선순위 ↓ — 정적 placeholder 만 |
| Multi-channel notification (SMS/푸시) | 단일 채널 (이메일/로그) 만 |
| k6 부하 테스트 | 시연만 가능하면 보너스 |

---

## 🎯 Critical Path Forward (남은 12일)

```
Day 1-2 (5/8~5/9)  : A9 Spring Boot 3.5.14 + A10 Dockerfile 5개 + B6 차트 5개
Day 3-4 (5/10~5/11): D1 GitHub Actions CI + 첫 클러스터 부트스트랩 + 검증
Day 5-7 (5/12~5/14): C1~C4 (JWT, Rate Limit, Circuit Breaker, Outbox Poller) + C5 notification 스텁
Day 8-9 (5/15~5/16): D2 OTel + D3 LGTM values + D4 Grafana 대시보드
Day 10  (5/17)     : D8 Newman E2E + 시연 리허설 1차
Day 11  (5/18)     : D7 정적 프론트 + 버그 잡기
Day 12  (5/19)     : D12 발표 자료 + 시연 리허설 2차
Day 13  (5/20)     : 발표
```

이 일정은 **공격적**. 막히는 부분 나오면 후순위 항목 (Phase D 의 Should/Could) 부터 컷.

---

## 💰 비용 진행

| 일자 | 누적 사용 (KRW) | 비고 |
|---|---|---|
| 2026-05-07 | 0 | 인프라 미부트스트랩 |
| 2026-05-08 (오전) | 0 | 동일 |
| 2026-05-08 (오후) | **시작** | terraform apply 완료. 시간당 ~553 KRW. EC2 stop 직후 시간당 ~180 KRW |

⚠️ 첫 부트스트랩 시점부터 시간당 ~553원 청구. **destroy/bootstrap 운영 정책** (CLAUDE.md §5) 준수 필수.

---

## 📌 변경 이력

| 일자 | 변경 |
|---|---|
| 2026-05-10 | 어제의 3개 sync 이슈 모두 fix: (A) platform-of-apps → 3 Apps (recurse:false), (B) apps-project Namespace whitelist, (C) 4 차트 serviceaccount.yaml whitespace trim 버그. 검증 대기. |
| 2026-05-08 | B-2d/e/f 3개 backend 차트 + B-2c 리팩터 (ports list 패턴, 4 charts 공통 templates). 4개 차트 lint 통과. |
| 2026-05-08 | B-2c user-api-gateway Helm 차트 작성 (Chart.yaml + values.yaml + 5 templates). |
| 2026-05-08 | Phase B ID 체계 통일: B1~B8 → B-1a~g, B6a~e → B-2c~g (sub-phase 일관성 확보). |
| 2026-05-08 | D1-d GitHub Actions workflow 추가 (matrix + OIDC + ECR push). PowerShell 스크립트 영어로 재작성. 첫 terraform apply 성공. |
| 2026-05-08 | D1-a/b/c Terraform: ECR ×4 + KMS + lifecycle + GitHub OIDC provider + assume role + 노드 ECR Pull 권한. |
| 2026-05-08 | B-2b 4개 서비스 Dockerfile + .dockerignore. 멀티스테이지 + Spring Boot layered jar + non-root + healthcheck 패턴. |
| 2026-05-08 | A9 Spring Boot 3.3.0 → 3.5.14 업그레이드 완료. Gradle wrapper 누락 fix 포함. |
| 2026-05-08 | 백로그 파일 신규 작성 (BACKLOG.md) |
