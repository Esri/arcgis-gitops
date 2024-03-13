output "cluster_name" {
  value       = aws_eks_cluster.cluster.name
  description = "EKS cluster name"
}

output "aws_region" {
  value       = data.aws_region.current.name
  description = "AWS region"
}

output "cluster_endpoint" {
  value       = aws_eks_cluster.cluster.endpoint
  description = "EKS cluster endpoint"
}

output "oidc_arn" {
  value       = aws_iam_openid_connect_provider.eks_oidc.arn
  description = "EKS cluster OIDC provider ARN"
}
