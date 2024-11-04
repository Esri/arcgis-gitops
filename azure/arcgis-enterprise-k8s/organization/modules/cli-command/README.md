<!-- BEGIN_TF_DOCS -->
# Terraform module cli-command

The module executes an Enterprise Admin CLI command in a Kubernetes pod.

## Providers

| Name | Version |
|------|---------|
| null | n/a |

## Resources

| Name | Type |
|------|------|
| [null_resource.kubectl_exec](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| admin_cli_pod | Enterprise Admin CLI pod name | `string` | `"enterprise-admin-cli"` | no |
| command | The CLI command and arguments to run | `list(string)` | n/a | yes |
| namespace | Kubernetes namespace | `string` | n/a | yes |
<!-- END_TF_DOCS -->