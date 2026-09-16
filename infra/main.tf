terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "bobpick-terraform-state-3rd-han"
    key            = "bobpick/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "bobpick-terraform-lock-3rd"
    encrypt        = true
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

