### AWS Architecture
![AWS デプロイアーキテクチャ](images/AWS-arch.png)

### IAM 정책
- terraform을 실행하려면 이하와 같은 IAM 정책이 필요하다
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
- IAM Role관련 권한 정책
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

### aws cli
- terraform에서는 aws-cli aws confiture을 통해서 확인정보를 읽어들임
```terminal
➜  ktcloud-sptingboot-msa-market-service git:(master) brew install aws-cli
```
- CLI전용의IAM Secret Key와ap-northeast-2리젼을 입력한다
```terminal
➜  ktcloud-sptingboot-msa-market-service git:(master) aws configure
```

### 키페어
- 키페어를 위한 쉘을 가동한다
```terminal
➜  provisioning git:(master) bash ssh-key-gen.bash
```

### NLB을 클러스터에 등록하기 위한 IAM 롤
- EKS가 아니라、EC2에서 구축한 클러스터는 NLB를 등록하기 위해 노드에 이하의 IAM정책이 필요하다
https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.2/docs/install/iam_policy.json
- 「ktcloud-cluster-node-role」의IAM Role에 아까 IAM정책을 붙여서 준비하자

### Terrafrom
```terminal
➜  terraform git:(master) terraform plan
```
```terminal
➜  terraform git:(master) terraform apply
```
- Ansible의Playbook을 기동하기위한 리모트 호스트의 Fingerprint를 로컬 머신에 등록할 필요가 있다. 양쪽의 bastion에 ssh접속해서「yes」를 입력하자
```terraform
output "ap-northeast-2a-bastion-node-connect-command" {
  value = "ssh ec2-user@${aws_instance.ap-northeast-2a-bastion-node.public_ip} -i ~/.ssh/ktcloud-bastion-node-key"
}

output "ap-northeast-2b-bastion-node-connect-command" {
  value = "ssh ec2-user@${aws_instance.ap-northeast-2b-bastion-node.public_ip} -i ~/.ssh/ktcloud-bastion-node-key"
}
```

### Ansible
- inventory.iniがterraform의.tftpl에서 작성되어
- ping이 도달하는지 확인하다.
```terminal
➜  ansible git:(master) ansible all -m ping -i inventory.ini
```
- K8S의 클러스터 셋업하는 Playbook을 기동한다.
```terminal
➜  ansible git:(master) ansible-playbook -i inventory.ini main.yaml
```

### K8S Cluster
- 키페어는 같기 때문에 ssh에이전트를 등록한다
```terminal
➜  ktcloud-sptingboot-msa-market-service git:(master) ✗ ssh-add ~/.ssh/ktcloud-bastion-node-key
Identity added: /Users/kanei/.ssh/ktcloud-bastion-node-key (kanei@gim-yeonghoui-MacBookPro.local)
```
- 이하의output의 결과를 한번에 확인가능하다
```terraform
output "main-master-node-connect-command" {
  value = "ssh -A -J ec2-user@${aws_instance.ap-northeast-2b-bastion-node.public_ip} ec2-user@${aws_instance.ap-northeast-2b-master-node-01.private_ip}"
}
```
- 실제로 접속해서 확인하면
```terminal
[ec2-user@ip-10-0-4-212 ~]$ kubectl get nodes
NAME                                            STATUS   ROLES           AGE   VERSION
ip-10-0-2-149.ap-northeast-2.compute.internal   Ready    <none>          39m   v1.30.14
ip-10-0-2-63.ap-northeast-2.compute.internal    Ready    control-plane   40m   v1.30.14
ip-10-0-2-81.ap-northeast-2.compute.internal    Ready    control-plane   40m   v1.30.14
ip-10-0-4-196.ap-northeast-2.compute.internal   Ready    <none>          39m   v1.30.14
ip-10-0-4-212.ap-northeast-2.compute.internal   Ready    control-plane   40m   v1.30.14
ip-10-0-4-6.ap-northeast-2.compute.internal     Ready    <none>          39m   v1.30.14
```
- alb을 사용하기위한 로드밸런서도 기동중인 것을 확인할 수 있다.
```terminal
[ec2-user@ip-10-0-4-126 ~]$ kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
NAME                                            READY   STATUS    RESTARTS   AGE
aws-load-balancer-controller-5cdc56445f-9xn6t   1/1     Running   0          2m15s
aws-load-balancer-controller-5cdc56445f-gmrcr   1/1     Running   0          2m15s
```