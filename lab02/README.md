# Lab 02 - Yêu cầu 1: Terraform + GitHub Actions + Checkov

## Mục tiêu

- Triển khai hạ tầng AWS (VPC, Subnets, NAT Gateway, EC2, Security Groups) bằng **Terraform**
- Tự động hóa quy trình CI/CD với **GitHub Actions**
- Kiểm tra bảo mật mã nguồn Terraform với **Checkov**

---

## Kiến trúc hạ tầng

```
                        Internet
                           │
                    ┌──────▼──────┐
                    │   IGW       │
                    └──────┬──────┘
                           │
              ┌────────────▼────────────┐
              │         VPC             │
              │      10.0.0.0/16        │
              │                         │
              │  ┌─────────────────┐    │
              │  │  Public Subnet  │    │
              │  │   10.0.1.0/24   │    │
              │  │  ┌───────────┐  │    │
              │  │  │  Bastion  │  │    │
              │  │  │  (EC2)    │  │    │
              │  │  └───────────┘  │    │
              │  │  ┌───────────┐  │    │
              │  │  │NAT Gateway│  │    │
              │  │  └─────┬─────┘  │    │
              │  └────────┼────────┘    │
              │           │             │
              │  ┌────────▼────────┐    │
              │  │ Private Subnet  │    │
              │  │   10.0.2.0/24   │    │
              │  │  ┌───────────┐  │    │
              │  │  │App Server │  │    │
              │  │  │  (EC2)    │  │    │
              │  │  └───────────┘  │    │
              │  └─────────────────┘    │
              └─────────────────────────┘
```

| Thành phần | Loại | Mô tả |
|---|---|---|
| VPC | `aws_vpc` | Mạng riêng ảo, CIDR `10.0.0.0/16` |
| Public Subnet | `aws_subnet` | Chứa Bastion Host và NAT Gateway |
| Private Subnet | `aws_subnet` | Chứa App Server, không có Public IP |
| Internet Gateway | `aws_internet_gateway` | Cho phép Public Subnet ra internet |
| NAT Gateway | `aws_nat_gateway` | Cho phép Private Subnet ra internet |
| Bastion Host | `aws_instance` | Máy chủ jump, SSH từ ngoài vào |
| App Server | `aws_instance` | Máy chủ ứng dụng, chỉ SSH từ Bastion |
| VPC Flow Logs | `aws_flow_log` | Ghi lại toàn bộ traffic trong VPC |

---

## Cấu trúc thư mục

```
lab02/
├── .checkov.yaml                        # Cấu hình Checkov scan
├── .github/
│   └── workflows/
│       └── lab02-terraform.yml          # GitHub Actions pipeline
└── terraform/
    ├── main.tf                          # Root module, khai báo provider + gọi modules
    ├── variables.tf                     # Định nghĩa các biến đầu vào
    ├── outputs.tf                       # Các giá trị xuất ra sau khi apply
    ├── terraform.tfvars                 # Giá trị biến (chỉ dùng local, KHÔNG commit)
    └── modules/
        ├── vpc/
        │   ├── main.tf                  # VPC, Subnets, IGW, NAT GW, Flow Logs
        │   ├── variables.tf
        │   └── outputs.tf
        ├── security_group/
        │   ├── main.tf                  # Security Groups cho Bastion và App
        │   ├── variables.tf
        │   └── outputs.tf
        └── ec2/
            ├── main.tf                  # EC2 Bastion và App Server
            ├── variables.tf
            └── outputs.tf
```

---

## Luồng hoạt động CI/CD

```
Developer push code lên GitHub
            │
            ▼
┌───────────────────────┐
│  Job 1: Checkov Scan  │  ← Quét bảo mật toàn bộ code Terraform
│  (~1 phút)            │    Nếu có lỗi nghiêm trọng → dừng tại đây
└──────────┬────────────┘
           │ PASS
           ▼
┌───────────────────────┐
│ Job 2: Terraform Plan │  ← init → fmt → validate → plan
│  (~2 phút)            │    Lưu tfplan làm artifact
│                       │    Comment kết quả vào PR (nếu là PR)
└──────────┬────────────┘
           │ PASS
           ▼
┌───────────────────────┐
│  Chờ Approve          │  ← Reviewer xem kết quả plan
│  (thủ công)           │    Bấm Approve trên GitHub
└──────────┬────────────┘
           │ APPROVED
           ▼
┌───────────────────────┐
│ Job 3: Terraform Apply│  ← Tạo hạ tầng AWS thực tế
│  (~3-5 phút)          │    Chỉ chạy khi push vào nhánh main
└───────────────────────┘

Khi cần dọn dẹp (chạy thủ công):
┌───────────────────────┐
│Job 4: Terraform Destroy│ ← Xóa toàn bộ tài nguyên AWS
│  (~3 phút)            │
└───────────────────────┘
```

### Điều kiện chạy từng Job

| Job | Trigger | Điều kiện |
|---|---|---|
| Checkov Scan | Tất cả events | Luôn chạy |
| Terraform Plan | Sau Checkov pass | Luôn chạy |
| Terraform Apply | Sau Plan pass + Approve | Chỉ khi push vào `main` và plan có thay đổi |
| Terraform Destroy | `workflow_dispatch` | Chạy thủ công từ GitHub UI |

---

## Hướng dẫn chạy Local (trước khi push)

### Yêu cầu

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- [AWS CLI](https://aws.amazon.com/cli/)
- [Checkov](https://www.checkov.io/) (`pip install checkov`)

### Bước 1 — Cấu hình AWS credentials

```bash
aws configure
# AWS Access Key ID:     <your-access-key>
# AWS Secret Access Key: <your-secret-key>
# Default region name:   ap-southeast-1
# Default output format: json

# Kiểm tra kết nối
aws sts get-caller-identity
```

### Bước 2 — Cập nhật terraform.tfvars

```bash
# Lấy IP hiện tại của bạn
curl ifconfig.me
```

Mở file `lab02/terraform/terraform.tfvars` và sửa:

```hcl
key_name = "tên-keypair-của-bạn"   # EC2 Key Pair đã tạo trên AWS Console
my_ip    = "1.2.3.4/32"            # Thay bằng IP thực từ lệnh curl ifconfig.me
```

### Bước 3 — Chạy Checkov

```bash
cd lab02
checkov --directory terraform --config-file .checkov.yaml --compact
```

Kết quả mong đợi:
```
Passed checks: XX, Failed checks: 0, Skipped checks: 10
```

> Nếu có **Failed checks** → xem phần [Xử lý lỗi Checkov](#xử-lý-lỗi-checkov) bên dưới.

### Bước 4 — Triển khai Terraform

```bash
cd lab02/terraform

# Khởi tạo provider và modules
terraform init

# Kiểm tra và tự động format code
terraform fmt -recursive

# Kiểm tra cú pháp
terraform validate

# Xem trước thay đổi (không tạo gì cả)
terraform plan

# Tạo hạ tầng thật trên AWS
terraform apply
# Gõ "yes" khi được hỏi xác nhận
```

### Bước 5 — Kiểm tra kết quả

```bash
# Xem IP các máy vừa tạo
terraform output

# Kết quả ví dụ:
# bastion_public_ip = "54.x.x.x"
# app_private_ip    = "10.0.2.x"
# nat_gateway_ip    = "13.x.x.x"
# vpc_id            = "vpc-xxxxxxxx"

# SSH vào Bastion
ssh -i ~/.ssh/tên-keypair.pem ec2-user@<bastion_public_ip>

# SSH vào App Server (từ bên trong Bastion)
ssh -i ~/.ssh/tên-keypair.pem ec2-user@<app_private_ip>
```

### Bước 6 — Dọn dẹp sau khi test

```bash
terraform destroy
# Gõ "yes" để xác nhận xóa toàn bộ tài nguyên
```

> ⚠️ **Quan trọng:** Destroy xong trên local rồi mới push lên GitHub để tránh trùng resource khi GitHub Actions apply lại.

---

## Hướng dẫn chạy GitHub Actions

### Bước 1 — Chuẩn bị AWS IAM User

1. Vào **AWS Console → IAM → Users → Create user**
2. Tên: `github-actions-lab02`
3. Gắn policy: `AdministratorAccess`
4. Tạo **Access Key** → lưu lại `Access Key ID` và `Secret Access Key`

### Bước 2 — Tạo EC2 Key Pair

1. Vào **EC2 → Key Pairs → Create key pair**
2. Đặt tên (ví dụ: `lab02-keypair`)
3. Tải file `.pem` về máy và lưu cẩn thận

### Bước 3 — Thêm GitHub Secrets

Vào **Repository → Settings → Secrets and variables → Actions → New repository secret**:

| Secret Name | Giá trị |
|---|---|
| `AWS_ACCESS_KEY_ID` | Access Key ID từ bước 1 |
| `AWS_SECRET_ACCESS_KEY` | Secret Access Key từ bước 1 |
| `MY_IP` | IP của bạn + `/32` (ví dụ: `100.31.16.42/32`) |
| `KEY_NAME` | Tên Key Pair từ bước 2 (ví dụ: `lab02-keypair`) |

### Bước 4 — Tạo GitHub Environment

1. Vào **Repository → Settings → Environments → New environment**
2. Đặt tên: `production`
3. Thêm GitHub username của bạn vào **Required reviewers**
4. Bấm **Save protection rules**

### Bước 5 — Push code lên GitHub

```bash
# Đảm bảo terraform.tfvars không bị commit
cat .gitignore | grep tfvars   # phải có dòng *.tfvars

# Push code
git add .
git status    # kiểm tra lần cuối, đảm bảo không có file tfvars
git commit -m "feat: lab02 yeu cau 1 - terraform + github actions + checkov"
git push origin main
```

### Bước 6 — Theo dõi pipeline

1. Vào tab **Actions** trên GitHub
2. Chọn workflow **Lab02 - Terraform CI/CD with Checkov**
3. Theo dõi từng job theo thứ tự

### Bước 7 — Approve để Apply

Khi Job 2 (Plan) hoàn thành:
1. Vào **Actions → workflow đang chạy → Review deployments**
2. Chọn environment `production`
3. Bấm **Approve and deploy**
4. Job 3 (Apply) sẽ tự động chạy

### Bước 8 — Dọn dẹp (khi xong lab)

1. Vào **Actions → Lab02 - Terraform CI/CD with Checkov**
2. Bấm **Run workflow** (góc phải)
3. Chọn nhánh `main` → **Run workflow**
4. Approve job Destroy khi được yêu cầu

---

## Xử lý lỗi Checkov

Có 10 check được **skip có chủ đích** trong `.checkov.yaml`. Mỗi check đều có lý do rõ ràng, chia làm 3 nhóm:

### Nhóm 1: Giới hạn kỹ thuật — không thể fix (3 check)

| Check ID | Nội dung check | Lý do skip |
|---|---|---|
| `CKV_AWS_88` | EC2 không được có Public IP | Bastion Host **bắt buộc phải có Public IP** để admin SSH từ internet vào. Nếu tắt Public IP thì không thể kết nối vào hạ tầng từ bên ngoài. |
| `CKV_AWS_135` | EC2 phải bật EBS Optimized | Tính năng EBS Optimized **chỉ hỗ trợ từ `t3.large` trở lên**. Instance `t3.micro` (Free Tier) không có tùy chọn này, bật vào sẽ báo lỗi khi apply. |
| `CKV_AWS_8` | EC2 phải dùng IAM Instance Profile thay vì Key Pair | Lab này dùng Key Pair để SSH trực tiếp cho đơn giản. IAM Instance Profile phù hợp cho production nhưng phức tạp hơn và không cần thiết ở môi trường học. |

### Nhóm 2: Không phù hợp môi trường Lab — chấp nhận được (4 check)

| Check ID | Nội dung check | Lý do skip |
|---|---|---|
| `CKV_AWS_382` | Security Group không được có egress rule `0.0.0.0/0` | EC2 **cần ra internet** để tải package (`yum update`, `pip install`...) qua NAT Gateway. Chặn egress hoàn toàn thì máy chủ không hoạt động được. Trong production nên giới hạn port cụ thể, nhưng với Lab này thì chấp nhận. |
| `CKV_AWS_158` | CloudWatch Log Group phải mã hóa bằng KMS | Mã hóa KMS phát sinh thêm chi phí (KMS key ~$1/tháng + phí gọi API). Không cần thiết cho môi trường Lab học tập. |
| `CKV_AWS_338` | CloudWatch Log Group phải giữ log > 1 năm | Yêu cầu retention > 1 năm phù hợp với môi trường production cần audit. Lab chỉ cần 7 ngày là đủ để quan sát và tiết kiệm chi phí lưu trữ. |
| `CKV2_AWS_41` | IAM Role phải yêu cầu MFA | Check này áp dụng cho IAM User login, không áp dụng cho Service Role. Role `flow-log` được dùng bởi dịch vụ AWS (VPC Flow Logs), không phải con người, nên không cần MFA. |

### Nhóm 3: False Positive — Checkov đọc sai (3 check)

| Check ID | Nội dung check | Lý do skip |
|---|---|---|
| `CKV_AWS_24` | Security Group không được mở SSH (`port 22`) từ `0.0.0.0/0` | Checkov **đọc sai** rule này. Rule SSH của App Server dùng `referenced_security_group_id` (chỉ cho phép từ Bastion SG), hoàn toàn không có `0.0.0.0/0`. Đây là hạn chế của Checkov khi phân tích `aws_vpc_security_group_ingress_rule`. |
| `CKV2_AWS_5` | Security Group phải được gắn vào một resource | Checkov không thể detect được Security Group đã gắn vào EC2 **thông qua module**. Trên thực tế SG đã được gắn vào Bastion và App Server trong `modules/ec2/main.tf`, nhưng Checkov chỉ nhìn trong phạm vi module `security_group` nên không thấy. |
| `CKV2_AWS_12` | Default Security Group của VPC phải rỗng | Checkov check rule này trên resource `aws_vpc` thay vì `aws_default_security_group`. Trong code đã có resource `aws_default_security_group` để lock down Default SG, nhưng Checkov không nhận ra vì check sai chỗ. |

---

## Biến môi trường

### Không nhạy cảm — khai báo thẳng trong workflow

| Biến | Giá trị mặc định | Mô tả |
|---|---|---|
| `aws_region` | `ap-southeast-1` | Region AWS |
| `project_name` | `nt548-lab02` | Tiền tố tên resource |
| `environment` | `dev` | Môi trường |
| `vpc_cidr` | `10.0.0.0/16` | CIDR của VPC |
| `public_subnet_cidr` | `10.0.1.0/24` | CIDR Public Subnet |
| `private_subnet_cidr` | `10.0.2.0/24` | CIDR Private Subnet |
| `instance_type` | `t3.micro` | Loại EC2 instance |

### Nhạy cảm — lưu trong GitHub Secrets

| Secret | Mô tả |
|---|---|
| `AWS_ACCESS_KEY_ID` | AWS IAM Access Key |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM Secret Key |
| `MY_IP` | IP admin để SSH vào Bastion |
| `KEY_NAME` | Tên EC2 Key Pair |

---


## Cấu hình S3 Backend cho GitHub Actions

> Bỏ qua phần này nếu chỉ muốn chạy **local**.

Mặc định, Terraform lưu `terraform.tfstate` **trên máy đang chạy**. Khi chạy GitHub Actions, mỗi job khởi động một runner mới hoàn toàn — nên nếu không có remote backend, job Destroy sẽ không thấy state và báo `0 destroyed`.

Giải pháp là dùng **S3 làm remote backend** để tất cả các job đều đọc/ghi chung một state file.

### Bước 1 — Tạo S3 Bucket và DynamoDB Table (chỉ làm 1 lần)

```bash
# Tạo S3 bucket (đặt tên duy nhất, ví dụ: nt548-lab02-tfstate)
aws s3api create-bucket \
  --bucket <TÊN-BUCKET-CỦA-BẠN> \
  --region ap-southeast-1 \
  --create-bucket-configuration LocationConstraint=ap-southeast-1

# Bật versioning để có thể rollback state nếu cần
aws s3api put-bucket-versioning \
  --bucket <TÊN-BUCKET-CỦA-BẠN> \
  --versioning-configuration Status=Enabled

# Tạo DynamoDB table để lock state (tránh 2 job chạy cùng lúc gây conflict)
aws dynamodb create-table \
  --table-name terraform-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ap-southeast-1
```

### Bước 2 — Uncomment block backend trong main.tf

Mở file `lab02/terraform/main.tf`, tìm đoạn được comment và uncomment + điền tên bucket:

```hcl
backend "s3" {
  bucket         = "<TÊN-BUCKET-CỦA-BẠN>"  # ← điền tên bucket vừa tạo
  key            = "lab02/terraform.tfstate"
  region         = "ap-southeast-1"
  dynamodb_table = "terraform-lock"
  encrypt        = true
}
```

### Bước 3 — Chạy terraform init để migrate state (nếu đã có state local)

```bash
cd lab02/terraform
terraform init -migrate-state
# Gõ "yes" khi được hỏi có muốn copy state lên S3 không
```

### Bước 4 — Push code lên GitHub

Sau khi uncomment và điền tên bucket, push code lên. GitHub Actions sẽ tự động đọc state từ S3 ở tất cả các job (Plan, Apply, Destroy).

### Cơ chế hoạt động

```
terraform init
  → đọc block backend "s3" trong main.tf
  → kết nối tới S3: <bucket>/lab02/terraform.tfstate
  → pull state về

terraform apply  →  push state (24 resources) lên S3
terraform destroy  →  pull state từ S3  →  destroy đúng 24 resources ✅
```

> ⚠️ **Lưu ý:** Khi quay về chạy local, hãy **comment lại** block backend trong `main.tf` và chạy `terraform init` lại. Nếu để nguyên backend S3 khi chạy local thì Terraform sẽ vẫn đọc/ghi state trên S3 — hoàn toàn được, nhưng cần đảm bảo AWS credentials local của bạn có quyền truy cập bucket đó.

---

## Lưu ý quan trọng

- File `terraform.tfvars` chỉ dùng ở **local**, không được commit lên GitHub
- Luôn chạy `terraform destroy` sau khi test xong để tránh phát sinh chi phí AWS
- `MY_IP` trong Secrets cần cập nhật nếu IP của bạn thay đổi (ISP cấp IP động)
- Nếu muốn làm nhóm, bật **S3 backend** trong `main.tf` để chia sẻ state file