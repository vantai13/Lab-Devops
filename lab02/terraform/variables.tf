variable "aws_region" {
  description = "AWS region để deploy (ap-southeast-1 = Singapore, gần VN nhất)"
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Tiền tố đặt tên cho tất cả resources, để tìm trên AWS Console"
  type        = string
  default     = "nt548-lab02"
}

variable "environment" {
  description = "Môi trường triển khai (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block của VPC — 10.0.0.0/16 cho phép 65536 địa chỉ IP"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR của Public Subnet — /24 = 256 địa chỉ"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR của Private Subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "instance_type" {
  description = "Loại EC2 instance — t3.micro nằm trong Free Tier"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Tên EC2 Key Pair đã tạo trên AWS Console (để SSH vào máy)"
  type        = string
}

variable "my_ip" {
  description = "IP của bạn để SSH vào Bastion (chạy: curl ifconfig.me rồi thêm /32)"
  type        = string
  sensitive   = true
}
