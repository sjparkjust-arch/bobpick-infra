# 1. Redis 서브넷 그룹
resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.environment}-redis-subnet-group"
  subnet_ids = [aws_subnet.private_db_a.id, aws_subnet.private_db_c.id]

  tags = {
    Name = "${var.environment}-redis-subnet-group"
  }
}

# 2. Redis 클러스터 (단일 노드 / 개발용)
resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "${var.environment}-redis-cache"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.redis.name
  security_group_ids   = [aws_security_group.db.id]

  tags = {
    Name = "${var.environment}-redis-cache"
  }
}
