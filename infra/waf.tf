resource "aws_wafv2_web_acl" "main" {
  name        = "bobpick-waf"
  description = "WAF for BobPick ALB"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # 1. AWS 관리형 규칙 - 일반적인 웹 공격(SQL Injection, XSS 등) 차단
  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "commonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # 2. 알려진 악성 IP 차단
  rule {
    name     = "AWS-AWSManagedRulesAmazonIpReputationList"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "ipReputationList"
      sampled_requests_enabled   = true
    }
  }

  # 3. Rate-based 규칙 - 동일 IP에서 5분간 2000회 초과 요청 시 차단 (DDoS 방어)
  rule {
    name     = "RateLimitRule"
    priority = 3

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "rateLimitRule"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "bobpickWAF"
    sampled_requests_enabled   = true
  }

  tags = {
    Name = "bobpick-waf"
  }
}

# ALB에 WAF 연결
resource "aws_wafv2_web_acl_association" "main" {
  resource_arn = aws_lb.main.arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}