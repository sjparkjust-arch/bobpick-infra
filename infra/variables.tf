# variables.tf

# 0. SSH 허용 IP (팀원 A 담당 - Bastion 접근용)
variable "allowed_ssh_ips" {
  type    = list(string)
  default = ["112.221.246.162/32"]
}

# 1. 공통 환경 변수
variable "environment" {
  description = "배포 환경 (dev, stage, prod)"
  type        = string
  default     = "dev"
}

# 2. S3 버킷 이름 (전 세계 유일해야 함)
variable "app_storage_bucket_name" {
  description = "Django 정적/미디어 파일 저장용 S3 버킷 이름"
  type        = string
  default     = "bobpick-main-s3"
}

# 3. RDS 설정값
variable "db_name" {
  description = "생성할 데이터베이스 이름"
  type        = string
  default     = "bobpickdb"
}

variable "db_username" {
  description = "DB 마스터 유저명"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "DB 마스터 비밀번호 (최소 8자 이상) — GitHub Secrets(TF_VAR_db_password)로 주입, 여기 default 없음"
  type        = string
  sensitive   = true
}

# 4. 네트워크 ID는 이제 하드코딩 대신 실제 리소스를 직접 참조합니다 (network.tf, security.tf 참고)
variable "db_subnet_ids" {
  description = "Private DB 서브넷 ID 목록 (최소 2개 AZ 필요)"
  type        = list(string)
  default     = []
}

variable "db_security_group_id" {
  description = "RDS 및 Redis용 보안 그룹 ID"
  type        = string
  default     = ""
}

variable "app_subnet_id" {
  description = "EC2가 배치될 Private App 서브넷 ID"
  type        = string
  default     = ""
}

variable "ec2_security_group_id" {
  description = "EC2에 적용될 방화벽(보안그룹) ID"
  type        = string
  default     = ""
}

variable "public_subnet_id" {
  description = "베스천 호스트가 들어갈 퍼블릭 서브넷 ID"
  type        = string
  default     = ""
}

variable "bastion_security_group_id" {
  description = "베스천 호스트용 보안 그룹 ID"
  type        = string
  default     = ""
}
