terraform {
  required_version = ">= 1.5"

  # ================================================================
  # REMOTE BACKEND — S3
  # ================================================================
  # HƯỚNG DẪN:
  #   - Chạy LOCAL  → comment toàn bộ block "backend" bên dưới
  #   - Chạy GitHub Actions → tạo S3 bucket + DynamoDB table trước,
  #     sau đó uncomment và điền tên bucket vào rồi push code
  #
  # Tạo S3 bucket (chỉ làm 1 lần):
  #   aws s3api create-bucket \
  #     --bucket nt548-lab02-tfstate \
  #     --region ap-southeast-1 \
  #     --create-bucket-configuration LocationConstraint=ap-southeast-1
  #   aws s3api put-bucket-versioning \
  #     --bucket nt548-lab02-tfstate-dedt \
  #     --versioning-configuration Status=Enabled
  #
  # Tạo DynamoDB table để lock state (chỉ làm 1 lần):
  #   aws dynamodb create-table \
  #     --table-name terraform-lock \
  #     --attribute-definitions AttributeName=LockID,AttributeType=S \
  #     --key-schema AttributeName=LockID,KeyType=HASH \
  #     --billing-mode PAY_PER_REQUEST \
  #     --region ap-southeast-1
  # ================================================================

  backend "s3" {
    bucket         = "nt548-lab02-tfstate-dedt"
    key            = "lab02/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "terraform-lock"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Repository  = "Lab-Devops"
    }
  }
}

module "vpc" {
  source = "./modules/vpc"

  project_name        = var.project_name
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
}

module "security_group" {
  source = "./modules/security_group"

  project_name = var.project_name
  vpc_id       = module.vpc.vpc_id
  my_ip        = var.my_ip
}

module "ec2" {
  source = "./modules/ec2"

  project_name      = var.project_name
  public_subnet_id  = module.vpc.public_subnet_id
  private_subnet_id = module.vpc.private_subnet_id
  bastion_sg_id     = module.security_group.bastion_sg_id
  app_sg_id         = module.security_group.app_sg_id
  instance_type     = var.instance_type
  key_name          = var.key_name
}
