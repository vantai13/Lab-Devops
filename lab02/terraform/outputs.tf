output "vpc_id" {
  description = "ID cua VPC"
  value       = module.vpc.vpc_id
}
output "bastion_public_ip" {
  description = "IP public cua Bastion Host"
  value       = module.ec2.bastion_public_ip
}
output "app_private_ip" {
  description = "IP private cua App Server"
  value       = module.ec2.app_private_ip
}
output "nat_gateway_ip" {
  description = "Elastic IP cua NAT Gateway"
  value       = module.vpc.nat_gateway_ip
}
