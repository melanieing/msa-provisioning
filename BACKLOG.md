# Market Service MSA — 백로그 & 진행 상황

> **마지막 갱신**: 2026-05-08
> 단일 진실 원천(SSOT). 작업 시작/완료 시 여기 갱신.

---

## 📊 스냅샷

| 항목 | 값 |
|---|---|
| **마감일** | 2026-05-20 |
| **남은 일수** | 12일 |
| **현재 위치** | A9 Spring Boot 3.5.14 업그레이드 완료. 다음: B-2b Dockerfile |
| **진행률** | Phase A 80%, Phase B 50%, Phase C 0%, Phase D 0% |
| **AWS 비용 사용량** | 0 / 66,000 KRW (아직 부트스트랩 X) |

### 다음 우선순위 (순서대로)

1. **🎯 [B-2b] 5개 서비스 Dockerfile + 멀티스테이지 빌드** — 이미지 없으면 차트가 의미 없음
2. **🎯 [B-2c] 5개 서비스 Helm 차트** (`msa-spring-boot/charts/services/*`) — ApplicationSet 자동 등록
3. **[D-1] GitHub Actions CI** (빌드 + 이미지 push + 매니페스트 image tag bump)
4. **[클러스터 첫 부트스트랩]** 실제 실행 + 검증
5. **[Phase C]** 백엔드 보강 (JWT, Rate Limit, Resilience4j, Outbox Poller)

### 🚨 위험 / 차단 요소

- 아직 한 번도 클러스터를 띄워본 적 없음 → **첫 부트스트랩 시 발견될 이슈** 시간 잡아먹을 가능성
- IAM Role `ktcloud-cluster-node-role` 이 콘솔에서 사전 생성됐는지 미확인
- Helm 차트 버전들이 cutoff 이후이긴 하나 실제 클러스터에서 깨질 가능성

---

## ✅ 완료 (역순, 최근 → 옛날)

### 2026-05-08
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
| A10 | **5개 서비스 Dockerfile** + 멀티스테이지 빌드 | 🎯 **다음** | 이미지 없으면 Helm 차트 의미 없음 |
| A+ | NAT Gateway 1개로 줄이기 (선택) | ⏳ 검토 | 시간당 60원 절감. HA 손해. 4h/일 운영 시 사실상 불필요 |

---

## 📋 Phase B — GitOps + 매니페스트

### B-1: 매니페스트 리포 + 플랫폼 (완료)

| ID | 항목 | 상태 | 비고 |
|---|---|---|---|
| B1 | 매니페스트 리포 폴더 구조 | ✅ 완료 | bootstrap/projects/platform/applications |
| B2 | App-of-Apps Root + Sync Wave | ✅ 완료 | 표준 정책 + finalizer 설정 |
| B3 | CNPG Helm + 5 PostgreSQL Cluster | ✅ 완료 | namespace `data` + Cluster CRD ×5 |
| B4 | Strimzi Kafka KRaft 3-broker | ✅ 완료 | 1.0.0 + Kafka 4.2.0 + KafkaTopic ×5 |
| B5 | Redis Operator + RedisCluster | ✅ 완료 | 3 master + 3 replica + 평문 Secret (학습용) |
| B7 | ApplicationSet (Git Generator) | ✅ 완료 | charts/services/* watch (아직 빈 상태) |
| B8 | Sync Policy 표준화 | ✅ 완료 | prune/selfHeal/CreateNamespace/ServerSideApply |

### B-2: 마이크로서비스 차트 (다음 차례)

| ID | 항목 | 상태 | 위치 | 우선순위 |
|---|---|---|---|---|
| B-2b | **4개 서비스 Dockerfile + .dockerignore** | 🟡 **진행 중** (2026-05-08) | 멀티스테이지 + Spring Boot layered jar |
| B6a | user-api-gateway Helm 차트 | ⏳ | `msa-spring-boot/charts/services/user-api-gateway/` | 후속 |
| B6b | product-service Helm 차트 | ⏳ | `charts/services/product-service/` | 후속 |
| B6c | order-service Helm 차트 | ⏳ | `charts/services/order-service/` | 후속 |
| B6d | inventory-service Helm 차트 | ⏳ | `charts/services/inventory-service/` | 후속 |
| B6e | notification-service Helm 차트 | ⏳ | `charts/services/notification-service/` | 후순위 (서비스 자체 미구현) |

각 차트 골격: Chart.yaml + values.yaml + templates/{deployment,service,configmap,hpa}.yaml

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
| D1 | GitHub Actions CI (빌드 + 테스트 + 이미지 push + tag bump) | ⏳ | Must |
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
| 2026-05-08 | 0 | 동일 |

⚠️ 첫 부트스트랩 시점부터 시간당 ~553원 청구. **destroy/bootstrap 운영 정책** (CLAUDE.md §5) 준수 필수.

---

## 📌 변경 이력

| 일자 | 변경 |
|---|---|
| 2026-05-08 | A9 Spring Boot 3.3.0 → 3.5.14 업그레이드 완료. Gradle wrapper 누락 fix 포함. |
| 2026-05-08 | 백로그 파일 신규 작성 (BACKLOG.md) |
