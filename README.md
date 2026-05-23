# NT548 Lab01 — Infrastructure as Code trên AWS

Deploy hạ tầng AWS tự động bằng **Terraform** VÀ **CloudFormation**.

## Kiến trúc triển khai

```
Internet
    │
    ▼
Internet Gateway
    │
    ▼
┌─────────────── VPC (10.0.0.0/16) ───────────────┐
│                                                   │
│  ┌── Public Subnet (10.0.1.0/24) ──┐             │
│  │  NAT Gateway (+ Elastic IP)      │             │
│  │  Bastion Host (EC2, Public IP)   │             │
│  └──────────────────────────────────┘             │
│           │ SSH                                    │
│  ┌── Private Subnet (10.0.2.0/24) ─┐             │
│  │  App Server (EC2, Private only)  │             │
│  └──────────────────────────────────┘             │
└───────────────────────────────────────────────────┘
```

---

## Yêu cầu

- AWS CLI đã cài và cấu hình (`aws configure`)
- Terraform >= 1.5
- EC2 Key Pair đã tạo trên AWS Console (tên: `vantai-keypair`)

---

## Phần A — Terraform

### Cấu trúc thư mục

```
lab01/terraform/
├── main.tf              # Root module, gọi các sub-modules
├── variables.tf         # Khai báo biến
├── outputs.tf           # Xuất thông tin sau deploy
├── terraform.tfvars     # Giá trị biến (KHÔNG commit file này nếu có secret)
└── modules/
    ├── vpc/             # VPC, Subnets, IGW, NAT, Route Tables
    ├── security_group/  # Bastion SG, App SG, Default SG
    └── ec2/             # Bastion Host, App Server
```

### Cách chạy Terraform

```bash
# 1. Lấy IP hiện tại của bạn
curl ifconfig.me

# 2. Sửa terraform.tfvars — điền IP vào my_ip
#    Ví dụ: my_ip = "203.162.0.1/32"
vim lab01/terraform/terraform.tfvars

# 3. Di chuyển vào thư mục terraform
cd lab01/terraform

# 4. Khởi tạo Terraform (tải providers)
terraform init

# 5. Xem trước những gì sẽ được tạo
terraform plan

# 6. Deploy hạ tầng
terraform apply

# 7. Xem thông tin sau deploy (IP Bastion, v.v.)
terraform output

# 8. Khi xong, xóa tất cả tài nguyên (tránh mất phí)
terraform destroy
```

### Sau khi deploy, SSH vào servers

```bash
# SSH vào Bastion Host
ssh -i ~/.ssh/vantai-keypair.pem ec2-user@<BASTION_PUBLIC_IP>

# SSH vào App Server (từ Bastion)
# Cách 1: Jump thẳng qua Bastion
ssh -i ~/.ssh/vantai-keypair.pem \
    -o ProxyJump=ec2-user@<BASTION_PUBLIC_IP> \
    ec2-user@<APP_PRIVATE_IP>

# Cách 2: SSH vào Bastion trước, rồi SSH tiếp vào App
ssh -A -i ~/.ssh/vantai-keypair.pem ec2-user@<BASTION_PUBLIC_IP>
# (Trong Bastion)
ssh ec2-user@<APP_PRIVATE_IP>
```

---

## Phần B — CloudFormation

### Cấu trúc

```
lab01/cloudformation/
├── 01-vpc.yaml            # Stack 1: VPC + Networking
├── 02-security-groups.yaml # Stack 2: Security Groups
├── 03-ec2.yaml            # Stack 3: EC2 Instances
└── deploy.sh              # Script deploy tự động
```

**Tại sao chia thành 3 stacks?** Vì CloudFormation dùng `Outputs + Export/Import` để các stack tham chiếu nhau. Stack EC2 cần biết Subnet ID từ Stack VPC — tách nhỏ giúp quản lý, update, và rollback từng phần độc lập.

### Cách chạy CloudFormation

```bash
# Cách 1: Dùng script tự động (khuyến nghị)
bash lab01/cloudformation/deploy.sh

# Cách 2: Deploy thủ công từng stack (phải theo thứ tự)

# Stack 1: VPC (phải deploy trước)
aws cloudformation deploy \
  --template-file lab01/cloudformation/01-vpc.yaml \
  --stack-name nt548-lab01-vpc \
  --parameter-overrides ProjectName=nt548-lab01 \
  --region ap-southeast-1

# Stack 2: Security Groups (sau khi VPC done)
aws cloudformation deploy \
  --template-file lab01/cloudformation/02-security-groups.yaml \
  --stack-name nt548-lab01-sg \
  --parameter-overrides ProjectName=nt548-lab01 MyIP="$(curl -s ifconfig.me)/32" \
  --region ap-southeast-1

# Stack 3: EC2 (sau khi SG done)
aws cloudformation deploy \
  --template-file lab01/cloudformation/03-ec2.yaml \
  --stack-name nt548-lab01-ec2 \
  --parameter-overrides ProjectName=nt548-lab01 KeyName=vantai-keypair \
  --region ap-southeast-1
```

### Xóa CloudFormation (theo thứ tự NGƯỢC lại)

```bash
# Phải xóa EC2 trước, VPC sau (ngược với lúc tạo)
aws cloudformation delete-stack --stack-name nt548-lab01-ec2 --region ap-southeast-1
aws cloudformation delete-stack --stack-name nt548-lab01-sg  --region ap-southeast-1
aws cloudformation delete-stack --stack-name nt548-lab01-vpc --region ap-southeast-1
```

---

## Chạy Test Cases

```bash
# Sau khi terraform apply thành công
bash tests/test_infrastructure.sh
```

---

## So sánh Terraform vs CloudFormation

| Tiêu chí | Terraform | CloudFormation |
|----------|-----------|----------------|
| Ngôn ngữ | HCL (HashiCorp) | YAML / JSON |
| Hỗ trợ cloud | Multi-cloud | AWS only |
| State management | File .tfstate | AWS quản lý tự động |
| Module hóa | `module {}` | Nested stacks / Exports |
| Rollback | Không tự động | Tự động khi stack fail |
| Giá | Miễn phí (OSS) | Miễn phí |
