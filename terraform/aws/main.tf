###############################
# ⚠️ テスト専用・絶対に apply しないこと
###############################

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ❌ 公開読み取りのS3（暗号化なし / PAB未設定）
resource "aws_s3_bucket" "public_bucket" {
  bucket = "scan-demo-public-bucket-${random_id.suffix.hex}"
  # 旧式ACLでpublic化（スキャナが検知しやすい）
  acl    = "public-read"

  tags = {
    purpose = "scanner-demo"
  }
}

# バケット名衝突回避用のランダムID（apply禁止だがvalidate用に残す）
resource "random_id" "suffix" {
  byte_length = 4
}

# ❌ 0.0.0.0/0 にSSH/3389開放のSG
resource "aws_security_group" "open_sg" {
  name        = "scan-demo-open-sg"
  description = "INSECURE: open to the world"
  vpc_id      = "vpc-12345678" # ダミー。applyは失敗する想定

  ingress {
    description = "SSH open to the world"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # ❌
  }

  ingress {
    description = "RDP open to the world"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # ❌
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # ❌ 全許可
  }

  tags = {
    purpose = "scanner-demo"
  }
}

# ❌ IAMポリシー：Action/Resourceがワイルドカード
data "aws_iam_policy_document" "insecure" {
  statement {
    sid       = "FullAdminEverythingEverywhere"
    actions   = ["*"]     # ❌
    resources = ["*"]     # ❌
    effect    = "Allow"
  }
}

resource "aws_iam_policy" "insecure_policy" {
  name   = "scan-demo-insecure-policy"
  policy = data.aws_iam_policy_document.insecure.json
}

# ❌ 暗号化OFF・Publicに見えるRDS
resource "aws_db_instance" "insecure_db" {
  identifier                 = "scan-demo-insecure-db"
  engine                     = "mysql"
  engine_version             = "8.0"
  instance_class             = "db.t3.micro"
  username                   = var.db_username
  password                   = var.db_password
  allocated_storage          = 20
  storage_encrypted          = false          # ❌ 暗号化無効
  publicly_accessible        = true           # ❌ パブリックアクセス
  skip_final_snapshot        = true
  vpc_security_group_ids     = [aws_security_group.open_sg.id]
  auto_minor_version_upgrade = false          # ❌ 自動アップグレード無効

  # ダミーのサブネット関連を省略（applyは失敗する前提）
  depends_on = [aws_security_group.open_sg]
}

# ❌ CloudTrail/CloudWatch ログ未設定 → 監査不足と見なされやすい（明示的に作らない）
# あえて何も作らないことで監査不足チェックを誘発
