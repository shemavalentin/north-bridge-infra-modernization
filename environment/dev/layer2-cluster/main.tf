// This file pulls the network outputs from Layer 1, provisions the EKS cluster module, and sets up the shared EFS file system

# Pull Layer 1 (Network) outputs via Remote State
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = var.tf_state_bucket
    key    = "networks/dev/terraform.tfstate"
    region = var.aws_region
  }
}

# Provision EKS Cluster and Managed Node Groups
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.24.0"

  cluster_name    = "${var.environment}-eks"
  cluster_version = var.cluster_version

  vpc_id     = data.terraform_remote_state.network.outputs.vpc_id
  subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids

  # Enable public access so that local machine can connect
  cluster_endpoint_public_access = true

  # Optional: Restrict public access to your specific IP  security
  # cluster_endpoint_public_access_cidrs = ["YOUR_IP/32"]

  enable_cluster_creator_admin_permissions = true


  eks_managed_node_groups = {
    default = {
      instance_types = ["t3.medium"]
      min_size       = 2
      max_size       = 5
      desired_size   = 2
      subnet_ids     = data.terraform_remote_state.network.outputs.private_subnet_ids
    }
  }
}

# Provision Amazon EFS for Shared Storage (Addresses Story E2)
resource "aws_efs_file_system" "shared_storage" {
  creation_token   = "${var.environment}-shared-efs"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  encrypted        = true

  tags = {
    Name = "${var.environment}-shared-efs"
  }
}

resource "aws_efs_mount_target" "mount_targets" {
  count           = length(data.terraform_remote_state.network.outputs.private_subnet_ids)
  file_system_id  = aws_efs_file_system.shared_storage.id
  subnet_id       = data.terraform_remote_state.network.outputs.private_subnet_ids[count.index]
  security_groups = [module.eks.cluster_primary_security_group_id]
}
