# outputs.tf

output "s3_bucket_name" {
  description = "생성된 S3 버킷 이름"
  value       = aws_s3_bucket.app_storage.id
}

output "rds_endpoint" {
  description = "RDS DB 접속 엔드포인트 주소"
  value       = aws_db_instance.mysql.endpoint
}

output "redis_endpoint" {
  description = "Redis 캐시 접속 엔드포인트 주소"
  value       = aws_elasticache_cluster.redis.cache_nodes[0].address
}