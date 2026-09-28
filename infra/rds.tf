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

# ==========================================
# 자동화: AWS Secrets Manager에 DB/Redis 엔드포인트 자동 주입
# ==========================================
resource "aws_secretsmanager_secret" "app_secret" {
  name                    = "bobpick/prod/env"
  recovery_window_in_days = 0 # destroy 시 즉시 삭제되도록 설정 (이름 충돌 방지)
}

resource "aws_secretsmanager_secret_version" "app_secret_val" {
  secret_id     = aws_secretsmanager_secret.app_secret.id
  secret_string = jsonencode({
    ALLOWED_HOSTS        = "*"
    DB_NAME              = "bobpickdb"
    DB_USER              = "admin"
    DB_PASSWORD          = var.db_password
    
    # 🌟 생성된 주소에서 포트번호(:3306)를 깔끔하게 잘라내고 자동 주입
    DB_HOST              = split(":", aws_db_instance.mysql.endpoint)[0] 
    
    # 🌟 생성된 Redis 주소를 자동으로 주입
    REDIS_HOST           = aws_elasticache_cluster.redis.cache_nodes[0].address 
    
    SECRET_KEY           = "3n6zq7(=jgmunpm1ozrdfrplk50fqacyz%t4z8q*qurao#pcz)"
    AWS_QUERYSTRING_AUTH = "False"
    
    # 🌟 주의: cloudfront 리소스 이름이 다르다면 s3.tf를 확인하고 맞춰주세요 (예: aws_cloudfront_distribution.cdn.domain_name)
    AWS_S3_CUSTOM_DOMAIN = aws_cloudfront_distribution.main.domain_name 
  })
}