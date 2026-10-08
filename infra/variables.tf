# variables.tf

# 0. SSH 허용 IP (Bastion 접근용)
#    실제 값은 저장소에 두지 않고 terraform.tfvars 또는 TF_VAR_allowed_ssh_ips 환경변수로 주입
variable "allowed_ssh_ips" {
  description = "Bastion SSH 접속을 허용할 관리자 IP 목록 (CIDR)"
  type        = list(string)
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
  default     = "bobpick-main-s3-3rd"
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


variable "public_subnet_id" {
  description = "베스천 호스트가 들어갈 퍼블릭 서브넷 ID"
  type        = string
  default     = ""
}


variable "django_secret_key" {
  description = "Django 애플리케이션 SECRET_KEY"
  type        = string
  sensitive   = true
}