# ALB 보안그룹 (인터넷에서 443/80 허용)
resource "aws_security_group" "alb" {
  name        = "bobpick-alb-sg"
  description = "Allow HTTPS/HTTP from internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "bobpick-alb-sg" }
}

# App(EC2/ASG) 보안그룹 (ALB에서만 8000 허용, SSH는 Bastion에서만)
resource "aws_security_group" "app" {
  name        = "bobpick-app-sg"
  description = "Allow traffic from ALB and Bastion"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "App port from ALB"
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description     = "SSH from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "bobpick-app-sg" }
}

# Bastion 보안그룹 (관리자 IP에서만 SSH — 본인 IP로 변경 필요)
resource "aws_security_group" "bastion" {
  name        = "bobpick-bastion-sg"
  description = "Allow SSH from admin IP only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from admin"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_ips # 아래 확인 방법 참고해서 실제 IP로 교체
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "bobpick-bastion-sg" }
}

# DB(RDS/Redis) 보안그룹 (VPC 내부에서만 접근 허용)
resource "aws_security_group" "db" {
  name        = "bobpick-db-sg"
  description = "Allow DB traffic from within the VPC"
  vpc_id      = aws_vpc.main.id

  # ==========================================
  # MySQL (3306) 허용 규칙
  # ==========================================
  ingress {
    description = "MySQL from within VPC"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    # 우리 VPC 전체 대역(10.0.0.0/16)을 허용하여 EKS 통신 에러 원천 차단
    cidr_blocks = ["10.0.0.0/16"]
  }

  # ==========================================
  # Redis (6379) 허용 규칙
  # ==========================================
  ingress {
    description = "Redis from within VPC"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    # 우리 VPC 전체 대역(10.0.0.0/16)을 허용하여 EKS 통신 에러 원천 차단
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "bobpick-db-sg" }
}