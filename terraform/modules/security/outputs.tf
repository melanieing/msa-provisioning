# security 모듈 출력 — compute 모듈이 EC2 에 SG 부착할 때 사용

output "cluster_node_sg_id" {
  value = aws_security_group.cluster_node.id
}

output "bastion_sg_id" {
  value = aws_security_group.bastion.id
}
