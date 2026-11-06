// Expose the cluster endpoint, CA certificate, and EFS ID so Layer 3 (Platform Add-ons) can use them

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "Kubernetes cluster name"
  value       = module.eks.cluster_name
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "efs_file_system_id" {
  description = "ID of the EFS shared file system"
  value       = aws_efs_file_system.shared_storage.id
}
