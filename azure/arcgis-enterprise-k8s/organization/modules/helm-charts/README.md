<!-- BEGIN_TF_DOCS -->
# Terraform module helm-charts

The module downloads the Helm Charts for ArcGIS Enterprise on Kubernetes tarball
from the repository specified in the index file, extracts the charts from the tarball
into the specified installation directory, and renames the extracted directory
to the Helm charts version.

The module skips the steps above if the Helm charts already exist in the installation directory.

## Requirements

On the machine where Terraform is executed:

* Current working directory must be the root of the "organization" module.
* Python 3.9 or later must be installed
* Path to azure/scripts directory must be added to PYTHONPATH
* ArcGIS Online credentials must be set by ARCGIS_ONLINE_PASSWORD and
  ARCGIS_ONLINE_USERNAME environment variables.

## Providers

| Name | Version |
|------|---------|
| local | n/a |
| null | n/a |

## Resources

| Name | Type |
|------|------|
| [null_resource.download_files](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.extract_files](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.rename_files](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [local_file.configure_yaml](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/file) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| index_file | Index file local path | `string` | n/a | yes |
| install_dir | Helm charts installation directory | `string` | `"./helm-charts/arcgis-enterprise"` | no |

## Outputs

| Name | Description |
|------|-------------|
| configure_yaml_content | Content of the configure.yaml file of the Helm charts |
| helm_charts_path | Path to the Helm Charts for ArcGIS Enterprise on Kubernetes |
| helm_charts_version | Version of Helm Charts for ArcGIS Enterprise on Kubernetes |
<!-- END_TF_DOCS -->