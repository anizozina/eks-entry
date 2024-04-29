
output "cluster_endpoint" {
  description = "Control Planeのエンドポイント"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Controle PlaneにアタッチしているSecurity Group"
  value       = module.eks.cluster_security_group_id
}

output "region" {
  value       = var.region
}

output "cluster_name" {
  value       = module.eks.cluster_name
}

output "irsa_iam_role_arn" {
  description = "IAM Role for Service AccountのARN"
  value = module.albc_irsa.iam_role_arn
}