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

# (기존 코드 유지: aws_s3_bucket, 암호화, 퍼블릭 액세스 차단 코드는 그대로 둡니다)

# -------------------------------------------------------------
# 4. CloudFront OAC (Origin Access Control) 생성
# -------------------------------------------------------------
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "${var.environment}-app-storage-oac"
  description                       = "OAC for App Storage (Static & Media)"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# -------------------------------------------------------------
# 5. CloudFront 배포(Distribution) 생성
# -------------------------------------------------------------
resource "aws_cloudfront_distribution" "cdn" {
  origin {
    domain_name              = aws_s3_bucket.app_storage.bucket_regional_domain_name
    origin_id                = aws_s3_bucket.app_storage.id
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  enabled         = true
  is_ipv6_enabled = true

  # 정적/미디어 파일 전용 캐시 동작 세팅
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_s3_bucket.app_storage.id

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    viewer_protocol_policy     = "redirect-to-https"
    min_ttl                    = 0
    default_ttl                = 86400    # 1일 캐싱
    max_ttl                    = 31536000 # 365일 캐싱
    response_headers_policy_id = "eaab4381-ed33-4a86-88ca-d9558dc6cd63"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# -------------------------------------------------------------
# 6. S3 버킷 정책 (CloudFront만 이 S3에서 파일을 읽을 수 있도록 허용)
# -------------------------------------------------------------
resource "aws_s3_bucket_policy" "allow_cloudfront_access" {
  bucket = aws_s3_bucket.app_storage.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "s3:GetObject"
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Resource  = "${aws_s3_bucket.app_storage.arn}/*" # 기존 S3 버킷(app_storage) 참조
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.cdn.arn
          }
        }
      }
    ]
  })
}

# -------------------------------------------------------------
# 7. 생성된 CloudFront 도메인 주소 출력 (장고 설정에 필요함)
# -------------------------------------------------------------
output "cloudfront_domain_name" {
  value       = aws_cloudfront_distribution.cdn.domain_name
  description = "Django settings.py에 들어갈 CloudFront 도메인 주소"
}
