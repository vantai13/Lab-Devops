#!/bin/bash
# =============================================================
# deploy_cloudformation.sh — Deploy tất cả CloudFormation stacks
# theo đúng thứ tự (VPC trước, SG sau, EC2 cuối)
# Cách chạy: bash lab01/cloudformation/deploy.sh
# =============================================================

set -e

# ——— Cấu hình — SỬA CÁC GIÁ TRỊ NÀY ———
PROJECT="nt548-lab01"
REGION="ap-southeast-1"
KEY_NAME="vantai-keypair"     # Tên Key Pair của bạn trên AWS Console
MY_IP=$(curl -s ifconfig.me)/32   # Tự động lấy IP hiện tại

echo "============================================"
echo " NT548 Lab01 — CloudFormation Deploy"
echo " Region  : $REGION"
echo " Project : $PROJECT"
echo " My IP   : $MY_IP"
echo "============================================"
echo ""

CF_DIR="lab01/cloudformation"

# ------ STACK 1: VPC ------
echo "🚀 [1/3] Deploy VPC Stack..."
aws cloudformation deploy \
  --template-file "$CF_DIR/01-vpc.yaml" \
  --stack-name "${PROJECT}-vpc" \
  --parameter-overrides \
      ProjectName="$PROJECT" \
      VpcCidr="10.0.0.0/16" \
      PublicSubnetCidr="10.0.1.0/24" \
      PrivateSubnetCidr="10.0.2.0/24" \
  --region "$REGION" \
  --capabilities CAPABILITY_IAM

echo "✅ VPC Stack done!"
echo ""

# ------ STACK 2: Security Groups ------
echo "🚀 [2/3] Deploy Security Group Stack..."
aws cloudformation deploy \
  --template-file "$CF_DIR/02-security-groups.yaml" \
  --stack-name "${PROJECT}-sg" \
  --parameter-overrides \
      ProjectName="$PROJECT" \
      MyIP="$MY_IP" \
  --region "$REGION"

echo "✅ Security Group Stack done!"
echo ""

# ------ STACK 3: EC2 Instances ------
echo "🚀 [3/3] Deploy EC2 Stack..."
aws cloudformation deploy \
  --template-file "$CF_DIR/03-ec2.yaml" \
  --stack-name "${PROJECT}-ec2" \
  --parameter-overrides \
      ProjectName="$PROJECT" \
      InstanceType="t2.micro" \
      KeyName="$KEY_NAME" \
  --region "$REGION"

echo "✅ EC2 Stack done!"
echo ""

# ------ Hiển thị kết quả ------
echo "============================================"
echo " 📋 Kết quả deploy:"
echo "============================================"
aws cloudformation describe-stacks \
  --stack-name "${PROJECT}-ec2" \
  --region "$REGION" \
  --query 'Stacks[0].Outputs' \
  --output table

echo ""
echo "🎉 Deploy thành công! Kiểm tra AWS Console để xem chi tiết."
echo ""
echo "💡 Cách SSH vào Bastion:"
BASTION_IP=$(aws cloudformation describe-stacks \
  --stack-name "${PROJECT}-ec2" \
  --region "$REGION" \
  --query 'Stacks[0].Outputs[?OutputKey==`BastionPublicIP`].OutputValue' \
  --output text)
echo "   ssh -i ~/.ssh/vantai-keypair.pem ec2-user@$BASTION_IP"
