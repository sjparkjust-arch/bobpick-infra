# Bastion용 SSM Role — SSM이 이 EC2를 관리할 수 있게 허용하는 역할
resource "aws_iam_role" "ssm_role" {
  name = "bobpick-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "bobpick-ssm-role"
  }
}

# AWS가 미리 만들어둔 SSM 관리 정책을 위 역할에 연결
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# EC2에 실제로 붙일 수 있는 형태(Instance Profile)로 감싸기
resource "aws_iam_instance_profile" "ssm_profile" {
  name = "bobpick-ssm-profile"
  role = aws_iam_role.ssm_role.name
}
