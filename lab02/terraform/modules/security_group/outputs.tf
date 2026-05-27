output "bastion_sg_id" {
  description = "ID của Bastion Security Group"
  value       = aws_security_group.bastion.id
}

output "app_sg_id" {
  description = "ID của App Security Group"
  value       = aws_security_group.app.id
}
