resource "aws_ecr_repository" "bobpick_app" {
  name                 = "bobpick/app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Environment = "prod"
    Project     = "bobpick"
  }
}