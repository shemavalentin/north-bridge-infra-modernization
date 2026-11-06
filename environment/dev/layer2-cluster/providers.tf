// o configure the AWS provider and point Layer 2 to its own isolated S3 state key

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "northbridge-terraform-state-dev"
    key            = "clusters/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "northbridge-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "Northbridge-EKS-Platform"
      Environment = var.environment
      Owner       = "DevOps-Team"
      CostCenter  = "Platform-Engineering-01"
    }
  }
}
