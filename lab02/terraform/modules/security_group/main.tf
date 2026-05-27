# Bastion Security Group — chỉ cho phép SSH từ IP của admin
resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-bastion-sg"
  description = "SG for Bastion Host - SSH only from admin IP"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.project_name}-bastion-sg" }
}

# Ingress rules tách riêng — Checkov khuyến nghị dùng aws_vpc_security_group_ingress_rule
resource "aws_vpc_security_group_ingress_rule" "bastion_ssh" {
  security_group_id = aws_security_group.bastion.id
  description       = "SSH only from admin IP"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = var.my_ip
}

resource "aws_vpc_security_group_egress_rule" "bastion_all_out" {
  security_group_id = aws_security_group.bastion.id
  description       = "Allow all outbound traffic"
  from_port         = -1
  to_port           = -1
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# App Server Security Group — chỉ SSH từ Bastion, port 3000 từ nội bộ VPC
resource "aws_security_group" "app" {
  name        = "${var.project_name}-app-sg"
  description = "SG for App Server - only accessible from Bastion"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.project_name}-app-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "app_ssh_from_bastion" {
  security_group_id            = aws_security_group.app.id
  description                  = "SSH only from Bastion SG"
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.bastion.id
}

resource "aws_vpc_security_group_ingress_rule" "app_port_3000" {
  security_group_id = aws_security_group.app.id
  description       = "App port 3000 from within VPC"
  from_port         = 3000
  to_port           = 3000
  ip_protocol       = "tcp"
  cidr_ipv4         = "10.0.0.0/16"
}

resource "aws_vpc_security_group_egress_rule" "app_all_out" {
  security_group_id = aws_security_group.app.id
  description       = "Allow all outbound traffic (qua NAT Gateway)"
  from_port         = -1
  to_port           = -1
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# Lock down default security group — Checkov yêu cầu
resource "aws_default_security_group" "default" {
  vpc_id = var.vpc_id
  tags   = { Name = "${var.project_name}-default-sg (LOCKED)" }
}
