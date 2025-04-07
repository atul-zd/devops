output "vpc_id" {
  value = module.vpc.vpc_id
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "iam_role_name" {
  value = module.iam.iam_role_name
}

output "region" {
  value = var.region
}

