data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Bastion Host — nằm ở Public Subnet, có Public IP để SSH từ internet
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [var.bastion_sg_id]
  key_name                    = var.key_name
  associate_public_ip_address = true

  # Checkov yêu cầu: bật monitoring và metadata IMDSv2
  monitoring = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 — bảo mật hơn IMDSv1
    http_put_response_hop_limit = 1
  }

  root_block_device {
    encrypted   = true # Checkov yêu cầu: mã hóa EBS volume
    volume_type = "gp3"
    volume_size = 30
  }

  tags = { Name = "${var.project_name}-bastion" }
}

# App Server — nằm ở Private Subnet, không có Public IP
resource "aws_instance" "app" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = var.private_subnet_id
  vpc_security_group_ids      = [var.app_sg_id]
  key_name                    = var.key_name
  associate_public_ip_address = false

  monitoring = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
    volume_size = 30
  }

  tags = { Name = "${var.project_name}-app" }
}
