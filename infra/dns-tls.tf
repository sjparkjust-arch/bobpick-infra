# 1. Route 53 도메인 호스팅 영역
resource "aws_route53_zone" "main" {
  name = "bobpick.cloud"
}

# 2. ACM SSL/TLS 인증서 발급
resource "aws_acm_certificate" "main" {
  domain_name       = "bobpick.cloud"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "bobpick-cert"
  }
}

# 3. 인증서 DNS 자동 검증용 CNAME 레코드
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.main.zone_id
}

# 4. ACM 인증서 검증 완료 대기
resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# 5. 가비아 등록용 네임서버 출력
output "route53_name_servers" {
  value       = aws_route53_zone.main.name_servers
  description = "가비아에 등록할 4개의 Route 53 네임서버"
}

# 6. EKS ALB Ingress 설정에 사용할 인증서 ARN 출력
output "acm_certificate_arn" {
  value       = aws_acm_certificate_validation.main.certificate_arn
  description = "Ingress yaml의 alb.ingress.kubernetes.io/certificate-arn 에 지정할 ARN"
}