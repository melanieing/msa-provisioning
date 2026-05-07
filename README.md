# msa-provisioning

Market Service MSA 프로젝트의 AWS 인프라 + Kubernetes 부트스트랩 코드.
Terraform 으로 AWS 리소스를 만들고, Ansible 로 EC2 위에 self-managed K8s 를 구축한다.

## 구성

```
msa-provisioning/
├── terraform/        # AWS 인프라 (VPC, EC2 8대, NLB, EFS, EBS, IAM)
├── ansible/          # K8s 부트스트랩 (kubeadm + Calico + Helm + AWS LBC + Argo CD)
├── ssh-key-gen.bash  # Bastion/노드 공통 SSH 키 생성 스크립트
└── images/           # 아키텍처 다이어그램
```

## AWS Architecture

![AWS 배포 아키텍처](images/AWS-arch.png)

---

## 사전 준비

### 1. IAM 정책 — Terraform 실행자에게 필요한 권한

Terraform 을 실행할 IAM 사용자/Role 에 다음 두 정책을 첨부한다.

**EC2 / VPC / ELB / EFS 관리 권한:**

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "EC2AndVPCManagement",
            "Effect": "Allow",
            "Action": [
                "ec2:*Vpc*",
                "ec2:*Subnet*",
                "ec2:*Gateway*",
                "ec2:*Route*",
                "ec2:*Address*",
                "ec2:*Instance*",
                "ec2:*SecurityGroup*",
                "ec2:*NetworkInterface*",
                "ec2:*KeyPair*",
                "ec2:*Image*",
                "ec2:*Volume*",
                "ec2:*Tag*"
            ],
            "Resource": "*"
        },
        {
            "Sid": "ELBManagement",
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:*"
            ],
            "Resource": "*"
        },
        {
            "Sid": "EFSManagement",
            "Effect": "Allow",
            "Action": [
                "elasticfilesystem:CreateFileSystem",
                "elasticfilesystem:CreateMountTarget",
                "elasticfilesystem:DeleteFileSystem",
                "elasticfilesystem:DeleteMountTarget",
                "elasticfilesystem:DescribeFileSystems",
                "elasticfilesystem:DescribeMountTargets",
                "elasticfilesystem:ModifyFileSystem",
                "elasticfilesystem:DescribeMountTargetSecurityGroups"
            ],
            "Resource": "*"
        }
    ]
}
```

**IAM Role 관련 권한** (Terraform 이 instance profile 을 만들고 기존 Role 을 PassRole 하기 위해):

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowReadSpecificRole",
            "Effect": "Allow",
            "Action": [
                "iam:GetRole",
                "iam:ListRoles",
                "iam:PassRole"
            ],
            "Resource": "*"
        },
        {
            "Sid": "AllowInstanceProfileManagement",
            "Effect": "Allow",
            "Action": [
                "iam:GetInstanceProfile",
                "iam:CreateInstanceProfile",
                "iam:AddRoleToInstanceProfile",
                "iam:RemoveRoleFromInstanceProfile",
                "iam:DeleteInstanceProfile"
            ],
            "Resource": "*"
        }
    ]
}
```

---

### 2. AWS CLI 설정

Terraform 은 `~/.aws/credentials` 또는 환경변수에서 자격증명을 읽어온다.

```bash
# Mac
brew install aws-cli

# 자격증명 + 기본 region 설정 (ap-northeast-2 입력)
aws configure
```

---

### 3. SSH 키페어 생성

Bastion + 모든 EC2 노드가 공유할 키 페어를 로컬에 생성한다.
`terraform apply` 전에 한 번만 실행하면 된다.

```bash
bash ssh-key-gen.bash
```

결과물:
- `~/.ssh/ktcloud-bastion-node-key`     (개인키)
- `~/.ssh/ktcloud-bastion-node-key.pub` (공개키 — Terraform 이 AWS 에 업로드)

---

### 4. NLB 등록용 IAM Role 사전 생성

⚠️ **이 Role 은 Terraform 으로 만들지 않는다.** AWS 콘솔에서 직접 만들어야 한다.

EKS 가 아닌 EC2 self-managed 클러스터에서 AWS Load Balancer Controller 를 쓰려면
노드에 다음 IAM 정책이 붙어있어야 한다:

https://github.com/kubernetes-sigs/aws-load-balancer-controller/blob/main/docs/install/iam_policy.json

이 정책을 첨부한 IAM Role 을 **`ktcloud-cluster-node-role`** 이라는 이름으로 만들어 둔다.
Terraform 이 이 Role 을 instance profile 로 감싸서 EC2 들에 부착한다.

---

## 인프라 배포

### 5. Terraform 으로 AWS 리소스 생성

```bash
cd terraform/
terraform init       # 첫 실행 시만
terraform plan       # 무엇이 만들어질지 미리 확인
terraform apply      # 실제 생성 (약 5분 소요)
```

> Ansible 이 SSH 로 노드에 접속하기 전에, **양쪽 Bastion 의 fingerprint 를 로컬에 등록**해야 한다.
> 한 번씩 SSH 로 접속해서 `yes` 를 입력하면 known_hosts 에 등록된다.
>
> ```hcl
> output "ap-northeast-2a-bastion-node-connect-command" {
>   value = "ssh ec2-user@${aws_instance.ap-northeast-2a-bastion-node.public_ip} -i ~/.ssh/ktcloud-bastion-node-key"
> }
>
> output "ap-northeast-2b-bastion-node-connect-command" {
>   value = "ssh ec2-user@${aws_instance.ap-northeast-2b-bastion-node.public_ip} -i ~/.ssh/ktcloud-bastion-node-key"
> }
> ```
>
> `terraform apply` 출력에 위 명령어가 나옴 → 그대로 복사해서 두 bastion 모두 한 번씩 접속.

---

### 6. Ansible 로 K8s 클러스터 부트스트랩

`inventory.ini` 는 `terraform apply` 시점에 `ansible.tf` 가 자동 생성한다 (templatefile 사용).

```bash
cd ansible/

# (선택) 모든 노드에 ping 으로 접근 가능한지 확인
ansible all -m ping -i inventory.ini

# 메인 playbook 실행 (약 10분 소요)
ansible-playbook -i inventory.ini main.yaml
```

`main.yaml` 이 11개 하위 playbook 을 차례로 실행:
1. OS 사전 설정 (swap off, 커널 모듈)
2. kubelet/kubeadm/kubectl + containerd 설치
3. main-master 에서 `kubeadm init` 실행 + Calico CNI 설치
4. 나머지 master 2대 + worker 3대를 join
5. Helm + AWS Load Balancer Controller + Argo CD 설치

---

## 검증

### 7. K8s 클러스터 동작 확인

키페어를 `ssh-agent` 에 등록해두면 `-J` (ProxyJump) 옵션이 매번 키 지정 없이 동작한다.

```bash
ssh-add ~/.ssh/ktcloud-bastion-node-key
```

`terraform apply` 출력의 `main-master-node-connect-command` 를 그대로 복사해서 main-master 에 접속:

```hcl
output "main-master-node-connect-command" {
  value = "ssh -A -J ec2-user@${aws_instance.ap-northeast-2b-bastion-node.public_ip} ec2-user@${aws_instance.ap-northeast-2b-master-node-01.private_ip}"
}
```

main-master 에서 `kubectl get nodes` 로 6 nodes Ready 확인:

```text
[ec2-user@ip-10-0-4-212 ~]$ kubectl get nodes
NAME                                            STATUS   ROLES           AGE   VERSION
ip-10-0-2-149.ap-northeast-2.compute.internal   Ready    <none>          39m   v1.30.14
ip-10-0-2-63.ap-northeast-2.compute.internal    Ready    control-plane   40m   v1.30.14
ip-10-0-2-81.ap-northeast-2.compute.internal    Ready    control-plane   40m   v1.30.14
ip-10-0-4-196.ap-northeast-2.compute.internal   Ready    <none>          39m   v1.30.14
ip-10-0-4-212.ap-northeast-2.compute.internal   Ready    control-plane   40m   v1.30.14
ip-10-0-4-6.ap-northeast-2.compute.internal     Ready    <none>          39m   v1.30.14
```

AWS Load Balancer Controller Pod 도 `Running` 인지 확인:

```text
[ec2-user@ip-10-0-4-126 ~]$ kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
NAME                                            READY   STATUS    RESTARTS   AGE
aws-load-balancer-controller-5cdc56445f-9xn6t   1/1     Running   0          2m15s
aws-load-balancer-controller-5cdc56445f-gmrcr   1/1     Running   0          2m15s
```

---

## Argo CD 사용

### 8. Argo CD CLI 설치 (main-master 에서)

```bash
sudo curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo chmod +x /usr/local/bin/argocd
argocd version --client
```

### 9. Argo CD 로그인

초기 admin 비밀번호는 K8s Secret 에 들어있다:

```bash
# admin 초기 비밀번호 추출
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo

# 로그인 (NodePort 30080 으로 노출됨)
argocd login <b-master-01-ip>:30080 --username admin --insecure
```

### 10. Application 상태 확인

```bash
argocd app list                            # 모든 Application 목록
argocd app get argocd/root-app             # root-app 상세
argocd app sync root-app --prune           # 강제 sync
```

> ⚠️ 일부 컴포넌트(예: Traefik)는 `Degraded` → `Healthy` 까지 5분 이상 걸릴 수 있다. 정상.

---

## 청소 (Reset)

### kubeadm 단계만 다시 하고 싶을 때

```bash
ansible-playbook -i inventory.ini k8s-clear.yaml
# 그 후 다시 main.yaml 실행
```

### AWS 리소스 전부 제거

```bash
cd terraform/
terraform destroy
```
