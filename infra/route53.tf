# 1. EKS Ingress가 생성한 ALB 자동 감지
data "aws_lb" "ingress_alb" {
  tags = {
    "elbv2.k8s.aws/cluster" = "bobpick-eks-3rd"
  }
}

# 2. Route 53 호스팅 영역 조회 (bobpick.cloud)
data "aws_route53_zone" "main" {
  name         = "bobpick.cloud"
  private_zone = false
}

# 3. 루트 도메인 연결 (https://bobpick.cloud)
resource "aws_route53_record" "root" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "bobpick.cloud"
  type    = "A"
  allow_overwrite = true

  alias {
    name                   = data.aws_lb.ingress_alb.dns_name
    zone_id                = data.aws_lb.ingress_alb.zone_id
    evaluate_target_health = true
  }
}
