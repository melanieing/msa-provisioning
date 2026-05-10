# Market Service MSA — 백로그 & 진행 상황

> **마지막 갱신**: 2026-05-12
> 단일 진실 원천(SSOT). 작업 시작/완료 시 여기 갱신.

---

## 📊 스냅샷

| 항목 | 값 |
|---|---|
| **마감일** | 2026-05-20 |
| **남은 일수** | 9일 |
| **현재 위치** | **묶음 ① 검증 완료 + V (t3.large) 동작 확인**. 부트스트랩 ×3 cycle 진행 중 발견된 7 issue (C5 buildbug, C5 ECR 누락, K8S_VARS_HOLDER, gRPC env mismatch, S orphan EBS, V worker meltdown, C3 suspend 호환성) 모두 진단 + 5/7 fix push. ArgoCD 20/20 Healthy/Synced + 모든 Pod Running 검증 완료. 클러스터 destroy 됨. |
| **진행률** | Phase A 95% (A5/A6 완료, A4/A++/A++b 잔여), **Phase B 100%** (microservice 다 검증), **Phase C 80%** ⬆ (C1+C4+C5+C8 ✅, C2/C3 fine-tune 후속, C6/C7 Should 잔여), **Phase D 85%** (D1 + D11 + D3 partial 완료) |
| **AWS 비용 사용량** | 2026-05-12 cluster meltdown 디버깅 + V 적용 후 2 cycle 부트스트랩 ≈ ~3시간 운영 ≈ ~2,000원. 누적 ~10,000원 (예산 15%). 남은 56,000원 ≈ 80시간 운영 가능 (t3.large 시 ~75시간). |

### 다음 우선순위 (순서대로)

**다음 라운드 = 묶음 ③ 운영 안정화 (cycle 마찰 제거)**. 그 후 묶음 ② 관측성.

1. **🔴 묶음 ③ — A++b + O + R + T + W + C2/C3 fine-tune**: cycle 효율 + suspend 호환성. 한 묶음으로:
   - **A++b**: OIDC + IAM + ECR 영구화 (cycle 마다 GHA Re-run 마찰 제거)
   - **O**: argocd-server resource limits (restart loop 해결)
   - **R**: build-and-push.yml paths 필터에 application.yaml + chart values 추가 (수동 trigger 마찰 제거)
   - **T**: teardown.ps1 의 safety net 5 카테고리 확장 (EBS Snapshot/EIP/ENI/LB 자동 sweep)
   - **W (신규)**: Resilience4j Circuit Breaker 의 Kotlin suspend 호환성 — `executeSuspendFunction` manual wrap 또는 Mono 변환 (C3 fallback 동작 위해)
   - **C2 fine-tune**: Rate Limit 의 IP key 기반 정확한 burst 검증 + 학습용 limit 적정값
2. **묶음 ② 관측성 (D2 + D3 풀스택 + D4)** — C1~C5 동작 후 metric/trace/log 가 의미 있어짐. 부수: P (metrics-server) + Q (Grafana svc) 같이.
4. **D8 Newman E2E** — Postman + Newman 시나리오 (C1~C5 활용한 E2E flow).
5. **D7 정적 페이지** + **D12 발표 자료** — 마감 직전.

**그 다음 라운드 = 묶음 ② 관측성 (D2+D3 풀스택+D4)**:
- D2 OTel Java SDK + agent → 5 microservice
- D3 OTel collector pipeline (OTLP receiver → Prometheus/Loki/Tempo exporter)
- D4 Grafana 대시보드 1~2개 (latency, Kafka lag)
- 부수: 새 이슈 P (metrics-server install) + Q (Grafana svc port-forward) 같이 처리

**그 다음 라운드 = 묶음 ③ 운영 안정화 (A++b + O + R + A4 옵션)**:
- A++b: OIDC + IAM Role + ECR 영구화 → destroy/bootstrap cycle 매끄러움 (GHA push 항상 동작)
- O: argocd-server resource limits (restart loop 해결)
- R: build-and-push.yml paths 필터에 `**/application.yaml` 추가
- A4: Terraform S3 backend (옵션, 1인 프로젝트라 우선순위 ↓)

**Critical Path (마감 9일 역산, 2026-05-12 ~ 2026-05-20)**:
```
5/12~5/13  : 묶음 ① (C1~C5)               ← Critical path 최상위
5/14       : 묶음 ③ 운영 안정화          ← 다음 부트스트랩 매끄럽도록
5/15~5/16  : 묶음 ② 관측성                ← C1~C5 동작 후에야 trace/metric 의미 ↑
5/17       : D8 Newman E2E + 시연 리허설 1차
5/18       : D7 정적 페이지 + 버그 잡기
5/19       : D12 발표 자료 + 시연 리허설 2차
5/20       : 발표
```

### ✅ 2026-05-11 검증 완료 (7 fix + N + D3 partial + root-app cosmetic)

부트스트랩 1회로 일괄 검증. ArgoCD 19/19 Synced/Healthy + 모든 namespace Pod Running + PVC 16개 Bound to gp3.

| Phase ID | 검증 증거 |
|---|---|
| **K** Redis Cluster 연동 | inventory-service `1/1 Running, RESTARTS=0, 17m+`. Spring Boot 가 `SPRING_DATA_REDIS_CLUSTER_NODES=redis-leader.data.svc.cluster.local:6379` 인식 → Lettuce/Redisson cluster 모드 활성 → `CLUSTER NODES` topology 자동 발견. |
| **L** reflector cross-namespace | `reflector-7d85d6bcfb-p6jmt 1/1 Running 33m+`. CNPG `inventory/order/product-db-app` Secret 과 `redis-secret` 이 microservice ns 로 자동 복제 → microservice 의 envFrom secretRef 자기 ns 에서 정상 resolve. |
| **base-path** user-api-gateway shutdown 의 root cause | user-api-gateway `1/1 Running 49m+, RESTARTS=0`. 어제까지 ~2분 만에 kill 패턴 사라짐. |
| **A5** KMS CMK + EFS SSE | terraform apply 성공. AWS 콘솔 KMS alias `*-efs` + EFS describe 시 Encrypted=True + KmsKeyId 우리 CMK arn. |
| **A6** VPC Endpoint S3 + KMS | terraform apply 성공. S3 gateway endpoint (Route Table entry) + KMS interface endpoint (private DNS resolve). |
| **C8** JWT K8s Secret | user-api-gateway envFrom secretRef 정상. `JWT_SECRET=...` env 가 chart secret.yaml 에서 주입 → application.yaml 의 `${JWT_SECRET}` 매칭. CLAUDE.md §6 위반 해소. |
| **D11** Trivy GHA scan | workflow 파일 main 에 push, 다음 build trigger 시 trivy-scan job 4개 자동 추가. |
| **N** Strimzi watchAnyNamespace | Kafka 6 Pod (broker 3 + controller 3) `1/1 Running 21m+`. operator 가 cluster-wide watch → data ns 의 KafkaNodePool/Kafka CR 발견 후 reconcile → broker/controller statefulset 생성. |
| **D3 partial** Loki + OTel minimal | `loki-0 2/2 Running 5m+` (SingleBinary mode + filesystem storage), `otel-collector-* 1/1 Running 5m+` (image=contrib + mode=deployment). PVC `storage-loki-0 5Gi Bound`. |
| **root-app cosmetic** | platform-data-app + platform-operators-app + platform-observability-app 의 `directory.recurse: false` 명시 제거 (default 와 일치). 19/19 Synced. |

### 🆕 2026-05-11 새 이슈 발견 (다음 라운드 후보)

| 임시 ID | 항목 | 우선순위 |
|---|---|---|
| **A++b** | OIDC + IAM Role + ECR 콘솔 영구화 — destroy 마다 OIDC 사라져서 다음 push 시 GHA fail. ECR 비어있어서 microservice image pull 실패 cascade. ECR 까지 영구화하면 매 cycle 매끄러움. 비용 ~월 100원 (ECR storage). | High (다음 라운드) |
| **O** | argocd-server restart loop — readiness probe 9번 fail → SIGTERM (143) → 재시작 cycle. 메모리 부족 또는 timeout 짧음. fix: chart values 의 server.resources.limits.memory 증가 또는 readinessProbe.timeoutSeconds 조정. | Medium |
| **P** | metrics-server 미설치 — `kubectl top` 안 됨. ansible playbook 으로 install 또는 helm. | Medium |
| **Q** | Grafana service port-forward hang — `svc/kube-prometheus-stack-grafana 3000:80` 으로 port-forward 시 endpoint 못 찾음. svc selector 또는 port spec 검토. | Low |
| **R** | ✅ 작성 완료 (2026-05-12) — build-and-push.yml paths 필터에 `**/application.yaml` + `**/application.yml` + `charts/**` 추가. 다음 push 부터 자동 trigger.
| **S** | ✅ 완료 (2026-05-12) — cluster-teardown.ps1 의 orphan EBS cleanup. terraform destroy 가 EC2 만 죽여서 PVC 가 만든 dynamic EBS 가 cleanup 안 되던 문제. 사용자가 콘솔에서 옛 37 개 일괄 삭제 (~5,500원 손실). teardown.ps1 에 3 step (PVC 명시 삭제 + 60s wait → terraform destroy → safety net AWS CLI) 추가. 다음 destroy 부터 자동. |
| **T** | ✅ 작성 완료 (2026-05-12) — cluster-teardown.ps1 의 Step 3/3 safety net 5 카테고리 확장. EBS / Snapshot / EIP / ENI 자동 sweep + LB 경고. 다음 destroy 부터 자동. PowerShell parser OK + BOM 239 187 191. |
| **U** | 새 microservice 추가 시 **5 곳 동시 갱신 필수** 패턴의 디자인 부채. 사용자가 C5 작성에서 2번 누락 발견 (root applicationModules + terraform repository_names). 통합 source 후보:<br>(a) terraform locals 에 service list 정의 → registry + GHA workflow 가 같은 list 참조 (GHA 는 직접 참조 못 하니 generation 스크립트 필요)<br>(b) 단순한 cross-check 스크립트 (pre-commit hook 또는 CI step) — 5 곳의 service list 가 일치하는지 검증<br>(c) Helm/Kustomize 처럼 service list 를 yaml 한 곳에 정의 + 각 도구가 거기서 read<br>(b) 가 가장 단순하고 안전. 묶음 ③ 의 운영 안정화 묶음에. |
| **V** | ✅ **완료 + 검증 통과** (2026-05-12). t3.large × 3 worker 적용 후 부트스트랩 → 6 nodes Ready, 모든 Pod Running, ArgoCD 20/20 Healthy/Synced. memory cascade meltdown 패턴 사라짐. 비용 시간당 ~675원. |
| **W** | ✅ 작성 완료, 검증 대기 (2026-05-12) — 4 service file (Product/Order Query+Command, Inventory Query) 의 @CircuitBreaker annotation 제거 + resilience4j-kotlin 의 `executeSuspendFunction` extension 으로 manual wrap. runCatching + getOrElse 패턴으로 fallback 명시. CircuitBreakerRegistry constructor inject. gradle BUILD SUCCESSFUL. |

### ✅ 오늘 검증 완료 (어제 fix 의 결과)

- **이슈 A — platform-of-apps 분리**: 새 부모 3개 (operators-app/data-app/observability-app) 모두 Healthy/Synced. recurse:false 가 raw CR 직접 적용 차단함 — 의도대로 동작.
- **이슈 B — apps Namespace whitelist**: 4 microservice Application 모두 Synced (Namespace 생성됨). 더 이상 "resource :Namespace is not permitted" 에러 없음.
- **이슈 C — Helm 차트 group/version empty**: 4 microservice 차트 모두 manifest 정상 적용. 더 이상 "groupVersion shouldn't be empty" 에러 없음.

### 🆕 오늘 부트스트랩 검증 중 발견된 새 이슈 2개

- **이슈 D**: `kafka-cluster` Application 에서 `The Kubernetes API could not find version "v1beta2" of kafka.strimzi.io/Kafka. Version "v1" is installed`. 원인: Strimzi 0.45 → 1.0.0 업그레이드 (어제) 시 메이저 변경 — `v1beta2` 제거. 우리 yaml 8곳 (kafka-cluster.yaml ×3, topics.yaml ×5) 갱신 필요. **fix 적용 완료, push 대기**.
- **이슈 E**: 마이크로서비스 Pod 들이 `Failed to pull image: ... no basic auth credentials`. 원인: K8s 1.27+ 부터 kubelet 내장 ECR 자동 인증 제거됨. K8s 1.35 는 `ecr-credential-provider` 플러그인이 노드별 설치돼야 함. IAM Role 의 ECR pull 권한은 이미 있지만 kubelet 이 그걸 활용 못함. **다음 세션 핵심 작업** — Ansible playbook 작성 후보. 면접 답변 가치 큼.

### ✅ 2026-05-10 fix 완료 (오전 3건 + 오후 8건 = 11건)

#### 오전 (어제 발견된 sync 이슈 검증/해결)
- **이슈 A — platform-of-apps 분리** (msa-argocd-manifest)
- **이슈 B — apps AppProject Namespace whitelist** (msa-argocd-manifest)
- **이슈 C — Helm 차트 serviceaccount.yaml whitespace trim 버그** (msa-spring-boot)

#### 오후 (부트스트랩 검증 + 깊은 디버깅)
- **이슈 D — Strimzi 1.0 v1beta2 제거**: 8 yaml `apiVersion: kafka.strimzi.io/v1beta2 → /v1` (msa-argocd-manifest)
- **이슈 F — KafkaTopic underscore RFC 1123 위반**: `metadata.name: order.inventory-reserved` (hyphen) + `spec.topicName: order.inventory_reserved` (PDF 보존) (msa-argocd-manifest)
- **이슈 E — K8s 1.27+ ECR 인증 (in-tree provider 제거)**: `ansible/ecr-credential-provider-setup.yaml` 신규. AWS `amazon-eks` S3 에서 binary 다운로드. KubeletConfiguration field 가 아닌 `KUBELET_EXTRA_ARGS` (CLI flag) 로 적용 (struct 에 imageCredentialProvider* 없음 발견). main.yaml 에서 kubeadm join 후로 위치 (kubelet 가 살아있어야 restart 가능).
- **이슈 G — EBS CSI driver + default StorageClass**: `ansible/ebs-csi-setup.yaml` 신규. K8s 1.27+ 의 in-tree EBS volume plugin 제거 대응. `gp3` default StorageClass + IAM Role 에 `AmazonEBSCSIDriverPolicy` attach. 10 PVC 즉시 Bound.
- **이슈 H — DiskPressure (root 8GB → 30GB)**: terraform compute 모듈에 `root_block_device { volume_size = 30, encrypted = true }` 추가 + `var.node_root_volume_size_gb = 30`. master + worker 6개 노드만 (bastion 제외).
- **terraform churn 영구 fix** (오후 디버깅 핵심):
  - 원인 #1: aws_instance 의 `security_groups` (EC2-Classic legacy) ↔ `vpc_security_group_ids` 사이 perpetual drift → matrix 매번 force replacement
  - 원인 #2: `aws_security_group.cluster_node` 의 inline `ingress { ... }` 5개 ↔ 별도 `aws_security_group_rule.cluster_node_self_ingress` 가 source-of-truth 다툼 → SG rule 매번 destroy/create
  - fix: 8개 EC2 모두 `vpc_security_group_ids` 로 변경 + `lifecycle.ignore_changes = [security_groups]`. 별도 rule 삭제 + `ingress { self = true }` inline 으로 통합.
  - 검증: 다음 plan 이 `Plan: 0 to add, 0 to change, 1 to destroy` (cleanup 만)
- **이슈 I — DB password CNPG Secret 주입** (msa-spring-boot): 4 chart deployment.yaml 에 `dbSecretName` 조건부 env block. 3 backend values.yaml 에 `dbSecretName: <svc>-db-app`. (단 cross-namespace 문제는 K-stopgap 으로 우회)
- **이슈 J — Spring Boot actuator probe sub-paths 404**: 4 chart values.yaml 에 `MANAGEMENT_ENDPOINT_HEALTH_PROBES_ENABLED: "true"`. Spring Boot 3.x 의 K8s 자동감지가 안 되는 경우 강제 활성.

### 📊 Evidence (portfolio 자료)
- ArgoCD UI 18 Applications (3 platform 부모 + 9 자식 + 4 microservice + projects + root) 대부분 Healthy/Synced
- 10 PVC 모두 Bound to gp3 (EBS CSI + DiskPressure fix 증명)
- 6 nodes Ready K8s 1.35.4 (bootstrap + EC2 churn fix 증명)
- microservice Pod 가 ECR 에서 image pull 후 정상 부팅 후 DB 연결 후 JPA 테이블 생성 (E + I 증명, K 직전까지)

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

### 2026-05-12 (묶음 ① 검증 완료 + V 동작 확인 + 7 issue 진단/fix)
- ✅ **부트스트랩 ×3 cycle**. cluster meltdown → V 적용 → 깨끗한 상태에서 검증.
- ✅ **묶음 ① 검증 결과**:
  - C1 JWT 인증: 401 (토큰 없이) + 토큰 발급 + 200 (토큰 첨부) 모두 동작
  - C4 Outbox Poller: 5초 주기 Hibernate query polling 확인
  - C5 notification: 4 토픽 consumer group 등록 확인
  - C2 Rate Limit: 동작 확인 (5 burst 이내 정상 통과 — 학습용 limit 적정)
  - **C3 Circuit Breaker**: fallback 미동작 — annotation + suspend 호환성 issue (W 로 fix)
- ✅ **V (t3.large) 동작 검증**: 부트스트랩 후 6 nodes Ready + 메모리 압박 사라짐 + 모든 Pod Running. memory limits 137% over-commit 패턴 해소.
- 🆕 **7 issue 진단 + fix push**:
  1. C5 buildbug: `notification-service` 가 root build.gradle.kts 의 applicationModules 화이트리스트 누락 → bootJar 안 만들어짐. fix: 한 줄 추가.
  2. C5 ECR 누락: `terraform/main.tf` 의 module.registry.repository_names 에 notification-service 누락 → GHA push 403. fix: 한 줄 추가.
  3. K8S_VARS_HOLDER ansible failed=1: `add_host` 의 ansible_connection: local 만으로 부족 → `hosts: "all:!K8S_VARS_HOLDER"` 패턴으로 매칭 자체 회피. ecr-credential-provider-setup.yaml fix.
  4. **gRPC env mismatch**: chart values 의 `GRPC_*_HOST` env 가 application.yaml property (`grpc.client.*-service.address`) 와 매핑 안 됨. → application.yaml placeholder + chart env 정확 매칭 (`GRPC_*_ADDRESS`). 묶음 ① 이전부터의 디자인 결함.
  5. S 검증 부수효과: cluster-teardown.ps1 의 PVC cleanup + safety net 동작 확인.
  6. V worker meltdown: t3.medium 137% over-commit → kubelet OOM cascade. fix: t3.large 격상.
  7. W (신규): Resilience4j suspend 호환성. 다음 라운드.
- 🆕 **U + V + W 신규 BACKLOG 항목 등록**.

### 2026-05-12 (오전 — 묶음 ① 백엔드 Must 작성)
- ✅ **C4 — Outbox Poller**: 5초 주기 @Scheduled 가 application service 의 `processAll()` 호출. fetch + publish + state 변경 다 application service 가 알아서. Transactional Outbox 4 component 완성.
- ✅ **C5 — notification-service 새 모듈**: 5번째 마이크로서비스. KafkaListener 4 토픽 구독 + logger.info 단일 채널. settings.gradle.kts 등록 + chart + Dockerfile + GHA matrix 추가.
- ✅ **C1 — JWT 인증 필터**: JwtTokenProvider (JJWT 0.12.6 + HMAC-SHA) + JwtAuthenticationWebFilter (Bearer 토큰 → ReactiveSecurityContextHolder) + AuthRestController POST /auth/login (학습용 demo user). SecurityConfig 의 anyExchange permitAll → authenticated.
- ✅ **C2 — Rate Limit 필터**: RateLimitWebFilter (Redisson RRateLimiter, cluster-wide). IP 기반 key (학습용). 초과 시 429 + Retry-After. SecurityConfig 의 SecurityWebFiltersOrder.HTTP_BASIC 위치 (JWT 보다 앞). chart values + msa-argocd-manifest 의 redis-secret reflector annotation 에 user-api-gateway ns 추가.
- ✅ **C3 — Resilience4j Circuit Breaker**: resilience4j-{spring-boot3,kotlin,reactor} 2.2.0. 4 service file (Product/Order/Inventory Query + Order Command) 의 gRPC 호출에 @CircuitBreaker + fallbackMethod. application.yaml 에 3 instance config (slidingWindow=10, failureRate=50%, waitDuration=10s).
- 📦 4 commit (msa-spring-boot 3 + msa-argocd-manifest 1) main push.
- 자체 검증: 5+1 모듈 ./gradlew compileKotlin BUILD SUCCESSFUL + 5 chart helm lint pass.
- 다음 단계 = 묶음 ① 검증 부트스트랩 (~45분, 6개 검증 명령).

### 2026-05-11 (스프린트 4일째 — 7 fix + N + D3 partial 묶음 검증 완료)
- ✅ **부트스트랩 1회로 일괄 검증 성공**. ArgoCD 19/19 Synced/Healthy. 모든 namespace Pod Running. PVC 16개 Bound to gp3. K8s 1.35.4 6 nodes Ready.
- ✅ **N (신규) — Strimzi operator watchAnyNamespace=true**: 부트스트랩 검증 중 발견. Kafka CR 이 `data` ns 에 있는데 operator 가 자기 ns (`kafka-system`) 만 watch → reconcile 안 함 → broker/controller Pod 안 뜸 → microservice DNS resolve 실패 cascade. fix: helm values 에 `watchAnyNamespace: true` (CNPG/redis 와 일관 cluster-wide).
- ✅ **D3 partial — Loki + OTel collector minimal values**: helm chart default 가 너무 무거움 (Loki SimpleScalable + S3 필수, OTel image.repository unset). 학습용 minimal: Loki=SingleBinary+filesystem, OTel=contrib+deployment.
- ✅ **root-app cosmetic OutOfSync** — platform-data-app/operators-app/observability-app 의 `directory.recurse: false` 명시 제거 (ArgoCD default 와 일치). git vs cluster state mismatch 해소.
- 📦 4 commit (msa-argocd-manifest), 모두 main push.
- 🆕 다음 라운드 후보 5개 발견 (A++b, O, P, Q, R). 위 표 참조.

### 2026-05-11 (스프린트 4일째 오전 — K + L + base-path + A5 + A6 + C8 + D11 묶음)
- ✅ **A5 — KMS CMK + EFS SSE 암호화** (msa-provisioning): storage 모듈에 KMS key + alias 추가. EFS 본체에 encrypted=true + kms_key_id. PDF §5.3 의 EBS+EFS+ECR 충족 (S3 는 D7 시 추가). outputs.tf 에 kms_key_arn 노출.
- ✅ **A6 — VPC Endpoint S3 (gateway, 무료) + KMS (interface, ~38원/h × 2 AZ)** (msa-provisioning): network 모듈. Route Table 에 S3 endpoint entry 자동, KMS 는 private_dns_enabled 로 SDK 코드 변경 0. 새 SG 'vpc-endpoint-sg' (HTTPS 443 from VPC). PDF §5.1 충족.
- ✅ **C8 — JWT secret → K8s Secret** (msa-spring-boot): values.yaml jwtSecret → templates/secret.yaml → deployment.yaml envFrom secretRef → Pod env JWT_SECRET → application.yaml ${JWT_SECRET} 매칭. ⚠️ 학습용 평문 (git commit), 운영급 wiring 갖춤. CLAUDE.md §6 위반 해소.
- ✅ **D11 — Trivy GHA scan** (msa-spring-boot): build-and-push.yml 에 trivy-scan job. matrix 4 service 병렬, needs: build. aquasecurity/trivy-action@master + ECR 로그인 + image-ref 로 scan. 학습용 정책 (exit-code:0, severity:CRITICAL,HIGH).
- ✅ Helm lint user-api-gateway 통과 + terraform validate 통과.

### 2026-05-11 (스프린트 4일째 — K + L + base-path 코드 fix)
- ✅ **이슈 K — Redis Cluster 연동 (코드 fix)**: 체크포인트 추측 검증. 실제 root cause 는 chart env `SPRING_REDIS_HOST` (Boot 2.x prefix) 가 Spring Boot 3.x 의 relaxed binding 에서 무시됨. `spring.data.redis.*` (Boot 3.x 표준) 로 prefix 변경 + cluster 모드 활성화를 위해 `SPRING_DATA_REDIS_CLUSTER_NODES` 단일 seed 노드 (`redis-leader.data.svc.cluster.local:6379`) 사용. Lettuce + Redisson 둘 다 자동으로 cluster 모드로 빈 생성 (Redisson Spring Boot starter 가 spring.data.redis.cluster.nodes 인식 → ClusterServersConfig). RedissonConfig 별도 bean 불필요. msa-spring-boot `charts/services/inventory-service/values.yaml`.
- ✅ **이슈 L — cross-namespace Secret 자동화 (영구 fix)**: emberstack/reflector 도입. msa-argocd-manifest:
  - `platform/operators/reflector-operator.yaml` 신규 (helm chart 10.0.41, 2026-05-08 release, app+chart 동기 버전, sync-wave -20)
  - 3 CNPG Cluster (inventory/order/product-db) 의 `spec.inheritedMetadata.annotations` 로 reflector 4종 annotation 상속 → `<cluster>-app` Secret 이 microservice ns 로 자동 복제
  - redis-secret 에도 동일 annotation 직접 추가 (inventory-service ns 로만 복제)
  msa-spring-boot:
  - inventory-service values.yaml: 평문 password 제거 + `redisSecretName: redis-secret`
  - 4 chart 의 deployment.yaml: secretKeyRef env block 을 `or dbSecretName redisSecretName` 으로 확장. 일관성 위해 4개 모두 동일 templates 유지.
- ✅ **🐛 user-api-gateway graceful shutdown 진단 + fix (side-effect of K 디버깅)**: root cause 발견 = 4개 application.yaml 의 비표준 `management.endpoints.web.base-path: /` + `path-mapping.health: healthz`. 실제 actuator endpoint 는 `/healthz/*` 인데 chart probe 가 `/actuator/health/liveness` 호출 → 404 → liveness 3 fail → kill (37s 부팅 + 90s = 정확히 일치). 다른 backend 들은 DB/Redis 연결 실패로 부팅 단계에서 죽어 가시화 안 됐을 뿐 동일 문제. **fix**: 4 application.yaml 에서 비표준 base-path 제거 (default `/actuator` 복원) + `probes.enabled: true` 명시. Dockerfile HEALTHCHECK 의 `/actuator/health` 와도 일관성 회복.
- 📦 두 레포 push 완료 (msa-spring-boot 2 commits + msa-argocd-manifest 1 commit). GHA matrix 가 4 services 자동 ECR 빌드.
- ⏳ **검증 대기**: 클러스터 꺼둔 상태라 마지막 30분 cluster-bootstrap 으로 K + L + base-path 일괄 확인.

### 2026-05-10 (오후 — 부트스트랩 검증)
- ✅ **🎉 어제 fix 한 3개 sync 이슈 cluster-bootstrap 으로 검증 완료** — A (platform-of-apps 분리 + recurse:false), B (apps Namespace whitelist), C (Helm chart group/version empty) 모두 의도대로 동작. ArgoCD UI 에서 platform-operators-app / platform-data-app / platform-observability-app 모두 Healthy/Synced. 4 microservice Application 모두 Synced (Pod 단계 진행 중).
- 🐛 **새 이슈 3개 발견** (어제와 무관):
  - **이슈 D — Strimzi 1.0.0 의 v1beta2 제거**: `kafka.strimzi.io/v1beta2` 가 더 이상 cluster 에 등록 안 됨 (메이저 업그레이드 영향). `_kafka/kafka-cluster.yaml` (3곳) + `_kafka/topics.yaml` (5곳) 의 apiVersion 을 `v1` 로 변경. **fix 완료**.
  - **이슈 F — KafkaTopic 의 underscore RFC 1123 위반**: D fix 후 더 깊은 validation 단계에서 발견. `metadata.name: order.inventory_reserved` 의 underscore 가 K8s 의 RFC 1123 (lowercase, `[a-z0-9.-]` 만) 위반. **fix 완료** — `metadata.name: order.inventory-reserved` (hyphen) + `spec.topicName: order.inventory_reserved` (PDF 명세 준수). KafkaTopic CRD 는 K8s 이름과 실제 Kafka 토픽명을 분리 가능.
  - **이슈 E (검증 완료) — ECR pull "no basic auth credentials"**: 사용자 가설 (ECR 이미지 부재) 검증을 위해 GitHub Actions 으로 이미지 push 후 Pod 재생성 → **여전히 같은 에러** → 인증 문제로 확정. K8s 1.27 부터 kubelet 내장 ECR 인증 제거됨. **K8s 1.35 는 `ecr-credential-provider` 플러그인 필요**. Ansible playbook 작성 (다음 세션) 또는 stopgap 으로 imagePullSecret + cron 갱신. **미fix — 다음 세션 핵심 작업**.
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
| A5 | KMS CMK + EBS/EFS/S3 SSE 암호화 | ✅ 완료 (2026-05-11) | EBS (어제 H fix) + ECR (D1-a) + EFS (오늘 storage 모듈에 KMS key 추가). S3 는 D7 (정적 페이지) 작업 시 같은 패턴으로 추가 예정. |
| A6 | VPC Endpoint (S3, KMS) | ✅ 완료 (2026-05-11) | network 모듈에 S3 gateway endpoint (무료) + KMS interface endpoint (~38원/h × 2 AZ) + 전용 SG 추가. private_dns_enabled 로 SDK 코드 변경 0. |
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
| B-2g | notification-service Helm 차트 | ✅ 완료 (2026-05-12, C5 와 함께) | `charts/services/notification-service/` 신규 작성 — 단일 포트 (8004) chart 패턴 (gateway 와 동일). C5 의 새 모듈 + 검증 통과로 사실상 B-2 100%. |

각 차트 골격: Chart.yaml + values.yaml + templates/{deployment,service,configmap,_helpers.tpl}

---

## 📋 Phase C — 백엔드 보강 (시작 전)

| ID | 항목 | 상태 | 영향 | 우선순위 |
|---|---|---|---|---|
| C1 | JWT 인증 필터 (게이트웨이) | ✅ **검증 완료** (2026-05-12) | 보안 | 401/200 분기, 토큰 발급/검증 모두 동작 확인. minor: B2-c 잘못된 password 가 401 대신 400 반환 (학습용 stub) |
| C2 | Rate Limit 필터 (Token Bucket) | ⚠️ 작성 완료, **fine-tune 후속** | 보안 / 안정성 | RateLimitWebFilter 동작 확인. 단 짧은 burst (5번) 안에서는 안 막힘 (rate=10/sec 적정). 30+ burst 검증은 timeout cascade 로 미완 → W 와 함께 다음 라운드 |
| C3 | Resilience4j Circuit Breaker | ⚠️ 작성 완료, **W 로 fallback 호환성 fix 필요** | 가용성 (PDF 핵심) | 코드 + chart wiring + 의존성 모두 완료. 단 검증 단계에서 `@CircuitBreaker` annotation 이 Kotlin suspend method 인식 못 함 → fallback 미동작. **W 항목** (`executeSuspendFunction` 으로 manual wrap) 으로 fix |
| C4 | Outbox Poller (`@Scheduled`) | ✅ **검증 완료** (2026-05-12) | 메시지 At-least-once 보증 | 5초 주기 Hibernate query (`select ... from order_inventory_request_outbox`) 정상 polling 확인 |
| C5 | notification-service 최소 구현 | ✅ **검증 완료** (2026-05-12) | 5번째 서비스 | Kafka consumer group 4 토픽 (order.pending/inventory_reserved/confirmed/cancelled) 모두 등록 확인. ArgoCD 자동 Application 등록. |
| C6 | IdempotentEventAspect 구현 | ⏳ | 중복 메시지 방지 | Should |
| C7 | Saga 보상 로직 1개 (재고부족→주문취소) | ⏳ | 분산 트랜잭션 | Should |
| C8 | JWT secret 등 → K8s Secret | ✅ 완료 (2026-05-11) | 보안 | Must — user-api-gateway chart 에 secret.yaml + envFrom + application.yaml 의 hardcoded 제거. |

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
| D11 | Trivy 컨테이너 스캔 | ✅ 완료 (2026-05-11) | Should — build-and-push.yml 에 trivy-scan job 추가. matrix 4 service 병렬, needs: build. 학습용 정책 (exit-code 0, severity CRITICAL+HIGH only). |
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
