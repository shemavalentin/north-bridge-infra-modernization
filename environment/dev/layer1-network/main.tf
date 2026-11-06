# provider "aws" {
#   region = var.aws_region

#   default_tags {
#     tags = {
#       Project     = "Northbridge-EKS-Platform"
#       Environment = var.environment
#       Owner       = "DevOps-Team"
#       CostCenter  = "Platform-Engineering-01"
#     }
#   }
# }

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.13.0"

  name = "${var.environment}-vpc"
  cidr = var.vpc_cidr

  azs             = var.azs
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway   = true
  single_nat_gateway   = var.environment == "dev" ? true : false
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Crucial tags for AWS Load Balancer Controller auto-discovery (Addresses Story D3)
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
    "karpenter.sh/discovery"          = "${var.environment}-eks"
  }
}