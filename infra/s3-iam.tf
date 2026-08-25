# 1. EC2 인스턴스가 사용할 IAM 역할(Role)
resource "aws_iam_role" "app_ec2_role" {
  name = "bobpick-app-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# 2. S3 접근 권한(AmazonS3FullAccess)을 역할에 부여
resource "aws_iam_role_policy_attachment" "s3_access" {
  role       = aws_iam_role.app_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# 3. EC2 시작 템플릿에 연결해줄 '인스턴스 프로파일'
resource "aws_iam_instance_profile" "app_ec2_profile" {
  name = "bobpick-app-ec2-profile"
  role = aws_iam_role.app_ec2_role.name
}