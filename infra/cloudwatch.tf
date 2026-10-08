# ------------------------------------------------------------------------------
# 1. CloudWatch 알람을 전송할 SNS Topic 생성
# ------------------------------------------------------------------------------
resource "aws_sns_topic" "alerts" {
  name = "bobpick-infra-alerts-topic"
}

# 알람 메일 구독 — 받는 주소는 변수 alert_emails로 주입 (variables.tf 참고)
resource "aws_sns_topic_subscription" "email" {
  for_each  = toset(var.alert_emails)
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = each.value
}

# ------------------------------------------------------------------------------
# 2. ASG CPU 사용률 알람 (평균 50% 초과 시 경고)
# ------------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "asg_high_cpu" {
  alarm_name          = "bobpick-asg-high-cpu-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60 # 1분 단위 측정
  statistic           = "Average"
  threshold           = 50 # CPU 50% 초과 시
  alarm_description   = "ASG CPU 사용률이 50%를 초과했습니다."
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app_asg.name # 👈 확인해주신 ASG 이름 매칭 완료
  }
}

# ------------------------------------------------------------------------------
# 3. ALB 5XX 에러 발생 알람 (서버 에러 감지)
# ------------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  alarm_name          = "bobpick-alb-5xx-error-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "ALB 타겟 그룹에서 5XX 서버 에러가 발생했습니다."
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix # 👈 확인해주신 ALB 이름 매칭 완료
  }
}

# ------------------------------------------------------------------------------
# 4. ALB Healthy Host(정상 서버) 수 부족 알람
# ------------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  alarm_name          = "bobpick-alb-healthy-hosts-alarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Minimum"
  threshold           = 2
  alarm_description   = "정상 작동 중인 App 인스턴스 수가 2대 미만으로 감소했습니다."
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    TargetGroup  = aws_lb_target_group.app.arn_suffix # 👈 확인해주신 타겟 그룹 이름 매칭 완료
    LoadBalancer = aws_lb.main.arn_suffix             # 👈 확인해주신 ALB 이름 매칭 완료
  }
}