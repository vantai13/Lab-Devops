resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-bastion-sg"
  description = "SG for Bastion Host - SSH only from admin IP"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH only from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]   
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-bastion-sg" }
}


resource "aws_security_group" "app" {
  name        = "${var.project_name}-app-sg"
  description = "SG for App Server - only accessible from Bastion"
  vpc_id      = var.vpc_id

  ingress {
    description     = "SSH only from Bastion SG"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  ingress {
    description = "App port 3000 from within VPC"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    description = "Allow all outbound (qua NAT Gateway)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-app-sg" }
}


resource "aws_default_security_group" "default" {
  vpc_id = var.vpc_id


  tags = { Name = "${var.project_name}-default-sg" }
}
