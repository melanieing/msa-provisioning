# Market Service MSA — 기술 스택 & 버전

> **마지막 검증일**: 2026-05-08
> 버전은 모두 GitHub releases API / ArtifactHub 직접 조회로 확인됨.

---

## 한눈에 보기

```
┌──────────────────────────────────────────────────────────────────┐
│ Application Layer                                                │
│   Java 21 LTS  ·  Kotlin 2.3.20  ·  Spring Boot 3.5.14 (예정)   │
│   Spring Cloud Gateway · Resilience4j · gRPC · QueryDSL          │
├──────────────────────────────────────────────────────────────────┤
│ Data Layer                                                       │
│   PostgreSQL 16  ·  Apache Kafka 4.2.0 (KRaft)  ·  Redis 7.4.8   │
├──────────────────────────────────────────────────────────────────┤
│ Platform Layer (K8s 위에 도는 운영 컴포넌트)                     │
│   Argo CD GitOps  ·  Helm 3.20.2  ·  Strimzi · CNPG · Redis Op   │
│   OpenTelemetry  ·  Prometheus  ·  Loki  ·  Grafana              │
├──────────────────────────────────────────────────────────────────┤
│ Kubernetes Runtime                                               │
│   K8s 1.35.4 (kubeadm self-managed on EC2) · Calico 3.32.0       │
│   containerd · AWS Load Balancer Controller                      │
├──────────────────────────────────────────────────────────────────┤
│ Infrastructure (AWS)                                             │
│   Terraform · Ansible · VPC · EC2 · NLB · NAT · EFS · EBS · IAM  │
└──────────────────────────────────────────────────────────────────┘
```

---

## 인프라 (msa-provisioning)

| 컴포넌트 | 버전 | 적용 상태 | 출처 / 비고 |
|---|---|---|---|
| Terraform | >= 1.6.0 | ✅ 적용 | `terraform/provider.tf` |
| AWS Provider | ~> 5.60 | ✅ 적용 | hashicorp/aws |
| Ansible | >= 2.14 | ✅ 사용 | (사용자 WSL 에 설치) |
| AMI | Amazon Linux 2 (`ami-087e08db3e40f7429`) | ✅ 적용 | ap-northeast-2 |
| EC2 인스턴스 | t3.medium (master/worker) + t3.nano (bastion) | ✅ 적용 | 변수화됨 |
| Region | ap-northeast-2 | ✅ 적용 | `var.region` |

---

## Kubernetes 런타임

| 컴포넌트 | 버전 | 적용 상태 | release | 비고 |
|---|---|---|---|---|
| **Kubernetes** | **1.35.4** | ✅ 적용 | 2026-04-15 | kubeadm self-managed (HA: 3 master + 3 worker) |
| **Calico CNI** | **3.32.0** | ✅ 적용 | 2026-04-30 | IP-in-IP 캡슐화. SG 자기참조 규칙 필요 |
| **Helm CLI** | **3.20.2** | ✅ 적용 | 2026-04-09 | Helm 3.x 마지막 안정 (4.x 도 release 됐으나 차트 호환성 위험) |
| **containerd** | distro 기본 | ✅ 적용 | — | Amazon Linux 2 의 yum 패키지 |
| **AWS Load Balancer Controller** | Helm latest | ✅ 적용 | — | EKS chart 사용 (kubeadm 클러스터에서도 동작) |

> **선택 근거 — K8s 1.36 (2026-04-22) 도 release 됐지만 latest-1 인 1.35 채택**: "널리 쓰이는 안정" 우선.

---

## GitOps + 매니페스트 (msa-argocd-manifest)

| 컴포넌트 | 버전 | 적용 상태 | release | 출처 |
|---|---|---|---|---|
| **Argo CD** | Helm 차트 latest | ✅ 적용 | — | argoproj/argo-helm |
| **Argo CD Application/ApplicationSet/AppProject** | argoproj.io/v1alpha1 | ✅ 적용 | — | App-of-Apps + ApplicationSet 혼용 |

### 운영 정책
- **Sync Policy 표준**: `automated.prune=true`, `selfHeal=true`, `CreateNamespace=true`, `ServerSideApply=true`, `finalizers: resources-finalizer.argocd.argoproj.io`
- **Sync Wave 순서**: AppProjects(-100) → platform-of-apps(-50) → operators(-20) → data(-10) → observability(0) → otel(5) → microservices(10)

---

## 플랫폼 컴포넌트 (Helm 차트로 설치)

| 컴포넌트 | 차트 버전 | 적용 상태 | release | 비고 |
|---|---|---|---|---|
| **CNPG (PostgreSQL Operator)** | **0.28.0** | ✅ 적용 | 2026-04-01 | cloudnative-pg chart |
| **Strimzi (Kafka Operator)** | **1.0.0** | ✅ 적용 | 2026-04-28 | 메이저 마일스톤. Kafka 4.x 만 지원 |
| **Redis Operator** | **0.24.0** | ✅ 적용 | 2026-03-13 | OT-CONTAINER-KIT |
| **kube-prometheus-stack** | **84.5.0** | ✅ 적용 | 2026-05-01 | Prometheus + Grafana + Alertmanager 묶음 |
| **Loki** | **7.0.0** (app: 3.6.7) | ✅ 적용 | — | grafana/loki helm chart |
| **OpenTelemetry Collector** | **0.153.0** | ✅ 적용 | 2026-04-30 | OTLP 게이트웨이 |

---

## 데이터 계층

| 컴포넌트 | 버전 | 적용 상태 | 비고 |
|---|---|---|---|
| **PostgreSQL** | **16** | ✅ 적용 | CNPG image `:16` (자동 minor 갱신). 5개 DB Cluster (Database per Service) |
| **Apache Kafka** | **4.2.0** | ✅ 적용 | KRaft 모드. Strimzi 1.0.0 강제 |
| **Kafka 토픽** | 5개 (PDF 부록 A) | ✅ 적용 | order.pending / inventory_reserved / confirmed / cancelled / notification.requested |
| **Redis (server)** | **7.4.8** | ✅ 적용 | `quay.io/opstree/redis:v7.4.8` |
| **Redis Cluster** | 3 master + 3 replica | ✅ 적용 | RedisCluster CRD |
| **Redis Exporter** | **1.83.0** | ✅ 적용 | Prometheus 메트릭 노출 |

---

## 관측성

| 컴포넌트 | 차트/이미지 버전 | 우선순위 | 비고 |
|---|---|---|---|
| **Prometheus** (메트릭) | kube-prometheus-stack 84.5.0 에 포함 | Must | |
| **Loki** (로그) | 7.0.0 (app 3.6.7) | Must | filesystem 또는 EBS 저장 |
| **Grafana** (시각화) | kube-prometheus-stack 에 포함 | Must | |
| **Alertmanager** (알림) | kube-prometheus-stack 에 포함 | Must | |
| **OpenTelemetry SDK** | OTel Java SDK | Must | 서비스에서 OTLP 송신 |
| **OpenTelemetry Collector** | 0.153.0 | Must | 마이크로서비스 → 백엔드 다리 |
| **Tempo** (트레이스) | 미설치 | Should | 시간 남으면 |
| **Mimir** (장기 메트릭) | 미설치 | Could | 시간 남으면 |

---

## 애플리케이션 (msa-spring-boot)

| 컴포넌트 | 버전 | 적용 상태 | 비고 |
|---|---|---|---|
| **Java** | 21 LTS | ✅ 적용 | jvmToolchain(21) |
| **Kotlin** | 2.3.20 | ✅ 적용 | `build.gradle.kts` |
| **Gradle** | 8.14.4 | ✅ 적용 (2026-05-08) | wrapper jar 누락 fix. Spring Initializr 에서 추출 |
| **Spring Boot** | **3.5.14** | ✅ 적용 (2026-05-08) | PDF 4.1절. `./gradlew assemble` 14개 모듈 통과 |
| **Spring Cloud Gateway** | 4.3.0 | ✅ 적용 | user-api-gateway. Spring Boot 3.5 짝 |
| **Resilience4j** | Spring Cloud 매칭 | ⏳ **예정** | Circuit Breaker, Fallback 미구현 |
| **gRPC** | grpc-java 매칭 | ✅ 적용 | 서비스 간 내부 통신 (PDF 허용 범위) |
| **QueryDSL** | kapt 통해 | ✅ 적용 | 동적 쿼리 |
| **Redisson** | 3.27.2 | ✅ 적용 | 분산 락 |
| **JJWT** | 0.12.6 | ✅ 적용 | JWT 토큰 |
| **AWS SES** (Spring Cloud) | 4.0.0 | ✅ 적용 (사용 X) | client-ses 모듈 |

### 마이크로서비스 5개

| 서비스 | 상태 | 비고 |
|---|---|---|
| user-api-gateway | 🟡 골격 (JWT/RateLimit 미구현) | 단일 진입점 + WebFlux + gRPC clients |
| product-service | ✅ gRPC 구현됨 | port 9001 |
| order-service | ✅ gRPC + Outbox 테이블 | port 9002. Saga 보상 로직 ⏳ |
| inventory-service | ✅ gRPC + Event Sourcing + Lua | port 9003 |
| notification-service | ❌ 미구현 | Phase B-3 또는 이후 |

---

## CI / CD

| 도구 | 버전 / 형태 | 적용 상태 |
|---|---|---|
| **Dockerfile** (4개 서비스) | 멀티스테이지 + layered jar + non-root | ✅ 적용 (2026-05-08) |
| **Base image** | `eclipse-temurin:21-jdk` (build) + `21-jre` (runtime) | ✅ 적용 |
| **Container Registry** | **AWS ECR** (Private + KMS 암호화 + lifecycle) | ✅ Terraform 코드 (2026-05-08) — apply 필요 |
| **GitHub Actions ↔ AWS** | **OIDC 페더레이션** (장기 access key 미사용) | ✅ Terraform 코드 (2026-05-08) — apply 필요 |
| **GitHub Actions** workflow | matrix 전략 (4 서비스 병렬) + OIDC + buildx GHA cache | ✅ 적용 (2026-05-08) — `.github/workflows/build-and-push.yml` |
| **매니페스트 image tag bump** | 자동화 (Argo CD Image Updater 또는 workflow 의 git push) | ⏳ 후속 |
| **ECR scan on push** | AWS 기본 취약점 스캔 | ✅ 적용 (scan_on_push=true) |
| **Trivy 보안 스캔** | latest action | ⏳ 미구현 (ECR scan 으로 대체 가능) |

---

## 테스트

| 도구 | 적용 상태 |
|---|---|
| JUnit 5 | ⏳ 0 테스트 |
| Mockito | ⏳ 미사용 |
| Testcontainers | ⏳ 미사용 |
| Postman + Newman | ⏳ E2E 미구현 |
| k6 (부하) | Won't (이번 스프린트 제외) |

---

## 정합성 핵심 의존성 (변경 시 함께 변경 필수)

| 한쪽이 바뀌면 → 같이 바꿔야 할 것 | 이유 |
|---|---|
| **Strimzi 차트 버전** ↔ **Kafka image 버전** | Strimzi 1.0.0 은 Kafka 4.x 만 지원. 3.x 와 1.0.0 조합은 불가 |
| **K8s 버전** ↔ **Calico 버전** | Calico 는 보통 K8s N-2 까지 지원. Calico 3.32 는 K8s 1.34/1.35/1.36 |
| **K8s 버전** ↔ **kubeadm-config.yaml.j2 의 kubernetesVersion** | 일치 안 하면 init 실패 |
| **CNPG 차트 버전** ↔ **PostgreSQL image** | CNPG 는 보통 PG 13~17 지원, image tag `:16` 사용 |

---

## 보안 / 시크릿

| 항목 | 현재 상태 | 향후 |
|---|---|---|
| Redis 비밀번호 | 평문 K8s Secret (학습용) | Sealed Secrets 또는 AWS Secrets Manager |
| JWT secret | hardcoded `application.yaml` | K8s Secret + envFrom |
| EBS / EFS / S3 암호화 | ❌ 미적용 | KMS CMK SSE 적용 (PDF 5.3절) |
| VPC Endpoint | ❌ 미적용 | S3, KMS (PDF 5.1절) |

---

## 미적용 / 예정 작업 (큰 항목)

- [x] ~~Spring Boot 3.3.0 → 3.5.14 업그레이드~~ (2026-05-08 완료)
- [x] ~~4개 서비스 Dockerfile~~ (2026-05-08 완료)
- [x] ~~ECR + KMS + GitHub OIDC Terraform 코드~~ (2026-05-08 완료, apply 필요)
- [ ] **5개 마이크로서비스 Helm 차트** 작성 (`charts/services/*`)
- [ ] **GitHub Actions workflow** (서비스별 빌드 + ECR push + 매니페스트 tag bump)
- [ ] **JWT 인증 필터** + **Rate Limit** (user-api-gateway)
- [ ] **Resilience4j Circuit Breaker** 통합
- [ ] **Outbox Poller** (`@Scheduled`)
- [ ] **notification-service** 구현
- [ ] **KMS CMK + SSE** (EBS/EFS/S3 암호화)
- [ ] **Sealed Secrets** 도입
- [ ] **Newman E2E 테스트**

---

## 검증 출처

| 카테고리 | URL |
|---|---|
| Kubernetes | https://github.com/kubernetes/kubernetes/releases |
| Calico | https://github.com/projectcalico/calico/releases |
| Helm CLI | https://github.com/helm/helm/releases |
| CNPG | https://github.com/cloudnative-pg/charts/releases |
| Strimzi | https://github.com/strimzi/strimzi-kafka-operator/releases |
| Redis Operator | https://github.com/OT-CONTAINER-KIT/helm-charts/releases |
| kube-prometheus-stack | https://github.com/prometheus-community/helm-charts/releases |
| Loki | https://artifacthub.io/packages/helm/grafana/loki |
| OpenTelemetry Collector | https://github.com/open-telemetry/opentelemetry-helm-charts/releases |
| Spring Boot | https://github.com/spring-projects/spring-boot/releases |

---

## 변경 이력

| 일자 | 변경 |
|---|---|
| 2026-05-08 | D1-d: GitHub Actions workflow (matrix + OIDC + ECR push + GHA layer cache). D1-a/b/c Terraform 모듈 (ECR + KMS + OIDC). |
| 2026-05-08 | B-2b 4개 서비스 Dockerfile 추가 (멀티스테이지 + Spring Boot layered jar + non-root + healthcheck) |
| 2026-05-08 | Spring Boot 3.3.0 → 3.5.14 업그레이드. Cloud Gateway 4.1.9 → 4.3.0. Gradle wrapper(8.14.4) 누락 fix |
| 2026-05-08 | tech stack 전체 → 2026-05 기준 최신 안정 버전으로 정합성 맞춤 (Strimzi 0.45→1.0, K8s 1.30→1.35, Calico 3.27→3.32, Helm 3.14→3.20.2, kube-prometheus-stack 65→84.5, Loki 6.10→7.0, OTel 0.110→0.153, Kafka 3.8→4.2, Redis 7.0→7.4.8) |
| 2026-05-08 | Phase B-1: platform/data 채움 (CNPG Cluster ×5 + Strimzi Kafka + Redis Cluster) |
| 2026-05-08 | Terraform module 화 (network/security/compute/loadbalancer/storage) |
| 2026-05-07 | EC2 stop/start/bootstrap/teardown PowerShell 스크립트 추가 |
| 2026-05-07 | Terraform 변수화 (variables.tf 13개 변수, provider.tf 신규) |
| 2026-05-07 | msa-argocd-manifest 레포 신규 생성 (bootstrap + projects + platform 골격) |
| 2026-05-07 | argocd-setup.yaml 의 매니페스트 레포 URL 본인 소유로 교체 |
