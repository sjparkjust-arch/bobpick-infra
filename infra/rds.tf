# 1. RDS가 위치할 서브넷 그룹 (Private DB 서브넷 2개)
resource "aws_db_subnet_group" "main" {
  name        = "${var.environment}-rds-subnet-group"
  subnet_ids  = [aws_subnet.private_db_a.id, aws_subnet.private_db_c.id]
  description = "DB Subnet Group for RDS"

  tags = {
    Name = "${var.environment}-rds-subnet-group"
  }
}

# 2. RDS MySQL 인스턴스
resource "aws_db_instance" "mysql" {
  identifier             = "${var.environment}-mysql-db"
  allocated_storage      = 20
  max_allocated_storage  = 50
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]
  skip_final_snapshot    = true
  publicly_accessible    = false
  multi_az               = true

  tags = {
    Name = "${var.environment}-mysql-db"
  }
}
