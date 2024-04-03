/**
 * # Terraform module load-balancer-controller
 * 
 * The module installs AWS Load Balancer Controller add-on to EKS cluster.
 *
 * See: https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html
 * 
 * ## Requirements
 * 
 * On the machine where terraform is executed must be installed AWS CLI, kubectl, helm, and Docker.
 */

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  oidc_provider = "oidc.eks.${data.aws_region.current.name}.amazonaws.com/id/${split("/", var.oidc_arn)[3]}"
  image_repo = "eks/aws-load-balancer-controller"
  image_tag = "v${var.controller_version}"
  helm_values = {
    "clusterName" = var.cluster_name
    "serviceAccount.create" = false
    "serviceAccount.name" = "aws-load-balancer-controller"
    "image.repository" = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/ecr-public/${local.image_repo}"
    "image.tag" = local.image_tag
    "enableShield" = var.enable_waf
    "enableWaf" = var.enable_waf
    "enableWafv2" = var.enable_waf
  }
  helm_values_str = join(" ", [for key, value in local.helm_values : "--set ${key}=${value}"])
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

resource "local_file" "service_account" {
  content = templatefile("${path.module}/service-account.yaml.tftpl",
  { role_arn = aws_iam_role.aws_eks_load_balancer_controller.arn })

  filename = "${path.module}/service-account.yaml"

  depends_on = [
    aws_iam_role.aws_eks_load_balancer_controller
  ]
}

resource "null_resource" "copy_public_ecr_image" {
  count = var.copy_image ? 1 : 0

  triggers = {
    always_run = "${timestamp()}"
  }
  
  provisioner "local-exec" {
    command = "chmod +x ${path.module}/copy-public-ecr-image.sh"
  }

  provisioner "local-exec" {
    command = "${path.module}/copy-public-ecr-image.sh ${local.image_repo}:${local.image_tag}"
  }
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
    command = "kubectl apply -f ${path.module}/service-account.yaml"
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
    command = "helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system ${local.helm_values_str}"
  }

  depends_on = [
    null_resource.copy_public_ecr_image,
    null_resource.service_account
  ]
}
