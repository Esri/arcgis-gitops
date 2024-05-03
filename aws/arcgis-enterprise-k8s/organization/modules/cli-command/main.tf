/**
 * # Terraform module cli-command
 * 
 * The module executes an Enterprise Admin CLI command in a Kubernetes pod.
 */

resource "null_resource" "kubectl_exec" {
  provisioner "local-exec" {
    command = "kubectl exec ${var.admin_cli_pod} --namespace=${var.namespace} -- ${ join(" ", var.command)}"
  }
}
