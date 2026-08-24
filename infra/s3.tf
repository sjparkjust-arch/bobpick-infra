# s3.tf

# 1. Django 미디어 및 정적 파일용 S3 버킷
resource "aws_s3_bucket" "app_storage" {
  bucket = var.app_storage_bucket_name

  tags = {
    Name        = "${var.environment}-app-storage"
    Environment = var.environment
  }
}

# 2. S3 버킷 암호화 활성화
resource "aws_s3_bucket_server_side_encryption_configuration" "app_storage_crypto" {
  bucket = aws_s3_bucket.app_storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 3. S3 퍼블릭 액세스 차단 (보안 기본 설정)
resource "aws_s3_bucket_public_access_block" "app_storage_pab" {
  bucket = aws_s3_bucket.app_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}