# loadbalancer 모듈 출력

output "nlb_dns_name" {
  description = "NLB 의 DNS 주소 (Ansible kubeadm-config 의 controlPlaneEndpoint 에 사용)"
  value       = aws_lb.this.dns_name
}
