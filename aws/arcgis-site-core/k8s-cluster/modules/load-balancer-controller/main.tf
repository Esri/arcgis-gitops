/**
 * # Terraform module load-balancer-controller
 * 
 * The module installs AWS Load Balancer Controller add-on to EKS cluster.
 *
 * See: https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html
 * 
 * ## Requirements
 * 
 * On the machine where terraform is executed must be installed AWS CLI, kubectl, and helm.
 */

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  oidc_provider = "oidc.eks.${data.aws_region.current.name}.amazonaws.com/id/${split("/", var.oidc_arn)[3]}"
  # image_repository = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/eks/aws-load-balancer-controller"
}

resource "aws_iam_policy" "locad_balancer_controller" {
  name_prefix = "AWSLoadBalancerControllerRole"
  description = "Policy for AWS Load Balancer Controller"
  policy      = file("${path.module}/AWSLoadBalancerController.json")
}

resource "aws_iam_role" "aws_eks_load_balancer_controller" {
  name_prefix = "AmazonEKSLoadBalancerControllerRole"
  description = "Amazon EKS Load Balancer Controller IAM role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_provider}:aud" : "sts.amazonaws.com",
            "${local.oidc_provider}:sub" : "system:serviceaccount:kube-system:aws-load-balancer-controller"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.cluster_name}/AmazonEKSLoadBalancerControllerRole"
  }
}

resource "aws_iam_role_policy_attachment" "aws_eks_load_balancer_controller" {
  role       = aws_iam_role.aws_eks_load_balancer_controller.name
  policy_arn = aws_iam_policy.locad_balancer_controller.arn
}

# resource "aws_ecr_pull_through_cache_rule" "eks" {
#   ecr_repository_prefix = "eks"
#   upstream_registry_url = "public.ecr.aws"
# }

resource "local_file" "service_account" {
  content = templatefile("${path.module}/service-account.yml.tftpl",
  { role_arn = aws_iam_role.aws_eks_load_balancer_controller.arn })

  filename = "${path.module}/service-account.yml"

  depends_on = [
    aws_iam_role.aws_eks_load_balancer_controller
  ]
}

# Ideally, instead of local-exec provisioner, the module should use kubernetes and helm terraform providers, 
# but the providers do not support initialization of k8s credentials after initialization of the providers.

resource "null_resource" "update_kubeconfig" {
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --region ${data.aws_region.current.name} --name ${var.cluster_name}"
  }

  depends_on = [
    aws_iam_role_policy_attachment.aws_eks_load_balancer_controller
  ]
}

resource "null_resource" "service_account" {
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = "kubectl apply -f ${path.module}/service-account.yml"
  }

  depends_on = [
    local_file.service_account,
    null_resource.update_kubeconfig
  ]
}

resource "null_resource" "helm_install" {
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = "helm repo add eks https://aws.github.io/eks-charts"
  }

  provisioner "local-exec" {
    command = "helm repo update eks"
  }

  provisioner "local-exec" {
    command = "helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system --set clusterName=${var.cluster_name} --set serviceAccount.create=false --set serviceAccount.name=aws-load-balancer-controller"
    # --set image.repository=${local.image_repository}
  }

  depends_on = [
    null_resource.service_account
  ]
}
