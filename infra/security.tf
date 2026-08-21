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

# DB(RDS/Redis) 보안그룹 (App 서버와 Bastion에서만 접근)
resource "aws_security_group" "db" {
  name        = "bobpick-db-sg"
  description = "Allow DB traffic from App servers and Bastion"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL from App"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id, aws_security_group.bastion.id]
  }

  ingress {
    description     = "Redis from App"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id, aws_security_group.bastion.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "bobpick-db-sg" }
}