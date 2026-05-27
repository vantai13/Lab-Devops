output "bastion_public_ip" {
  description = "Public IP của Bastion Host"
  value       = aws_instance.bastion.public_ip
}

output "app_private_ip" {
  description = "Private IP của App Server"
  value       = aws_instance.app.private_ip
}
