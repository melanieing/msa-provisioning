output "ap-northeast-2a-bastion-node-connect-command" {
  value = "ssh ec2-user@${aws_instance.ap-northeast-2a-bastion-node.public_ip} -i ~/.ssh/ktcloud-bastion-node-key"
}

output "ap-northeast-2b-bastion-node-connect-command" {
  value = "ssh ec2-user@${aws_instance.ap-northeast-2b-bastion-node.public_ip} -i ~/.ssh/ktcloud-bastion-node-key"
}

output "main-master-node-connect-command" {
  value = "ssh -A -J ec2-user@${aws_instance.ap-northeast-2b-bastion-node.public_ip} ec2-user@${aws_instance.ap-northeast-2b-master-node-01.private_ip}"
}
