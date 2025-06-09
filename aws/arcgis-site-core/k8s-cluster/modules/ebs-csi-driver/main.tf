/**
 * # Terraform module ebs-csi-driver
 * 
 * The module installs Amazon EBS CSI Driver add-on to EKS cluster.
 *
 * See: https://docs.aws.amazon.com/eks/latest/userguide/managing-ebs-csi.html
 *
 * ## Requirements
 * 
 * On the machine where terraform is executed must be installed AWS CLI and kubectl.
 */

# Copyright 2024 Esri
#
# Licensed under the Apache License Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

data "aws_region" "current" {}

locals {
  oidc_provider = "oidc.eks.${data.aws_region.current.name}.amazonaws.com/id/${split("/", var.oidc_arn)[3]}"
  is_gov_cloud = contains(["us-gov-east-1", "us-gov-west-1"], data.aws_region.current.name)
  arn_identifier = local.is_gov_cloud ? "aws-us-gov" : "aws"  
}

# IAM role that provides permission for Amazon EBS CSI plugin to make calls to AWS APIs. 
resource "aws_iam_role" "aws_ebs_csi_driver" {
  name_prefix = "AmazonEKS_EBS_CSI_DriverRole"
  description = "Amazon EBS CSI plugin IAM role"

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
            "${local.oidc_provider}:sub" : "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.cluster_name}/AmazonEKS_EBS_CSI_DriverRole"
  }
}

resource "aws_iam_role_policy_attachment" "aws_ebs_csi_driver_policy" {
  role       = aws_iam_role.aws_ebs_csi_driver.name
  policy_arn = "arn:${local.arn_identifier}:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# Install the Amazon EBS CSI Driver add-on.
resource "aws_eks_addon" "aws_ebs_csi_driver" {
  cluster_name             = var.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = aws_iam_role.aws_ebs_csi_driver.arn
}

resource "null_resource" "update_kubeconfig" {
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --region ${data.aws_region.current.name} --name ${var.cluster_name}"
  }
}

 # Create a storage classes referencing the gp3 EBS type.
resource "null_resource" "storage_class" {
  triggers = {
    always_run = "${timestamp()}"
  }

  # ??? kubectl delete storageclass gp2
  
  provisioner "local-exec" {
    command = "kubectl apply -f ${path.module}/sc_reclaim_delete.yaml"
  }

  provisioner "local-exec" {
    command = "kubectl apply -f ${path.module}/sc_reclaim_retain.yaml"
  }

  depends_on = [
    null_resource.update_kubeconfig
  ]
}
