<!-- BEGIN_TF_DOCS -->
# Terraform module monitoring

The module deploys Monitoring subsystem that include Azure Monitor workspace and Azure Managed Grafana instances.

1. Creates Azure Monitor Workspace.
2. Create data collection rule associations (DCRAs) for the AKS cluster and the default data collection rule of the monitor workspace.
3. Create Azure Managed Grafana instance.
4. Assign Grafana dashboard identity "Monitoring Data Reader" role to read data from the Azure Monitor Workspace.
5. Creates Prometheus rule groups with default recording rules.

See: https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/quickstart-deploy-application-gateway-for-containers-alb-controller

## Providers

| Name | Version |
|------|---------|
| azurerm | n/a |

## Resources

| Name | Type |
|------|------|
| [azurerm_dashboard_grafana.grafana](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/dashboard_grafana) | resource |
| [azurerm_monitor_alert_prometheus_rule_group.kubernetes_recording_rules_rule_group](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_alert_prometheus_rule_group) | resource |
| [azurerm_monitor_alert_prometheus_rule_group.node_recording_rules_rule_group](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_alert_prometheus_rule_group) | resource |
| [azurerm_monitor_alert_prometheus_rule_group.ux_recording_rules_rule_group](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_alert_prometheus_rule_group) | resource |
| [azurerm_monitor_data_collection_rule_association.dcra](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_data_collection_rule_association) | resource |
| [azurerm_monitor_workspace.prometheus](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_workspace) | resource |
| [azurerm_role_assignment.data_reader_role](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_kubernetes_cluster.site_cluster](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/kubernetes_cluster) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| azure_region | Azure region display name | `string` | n/a | yes |
| cluster_name | Name of the AKS cluster | `string` | n/a | yes |
| resource_group_name | AKS cluster resource group name | `string` | n/a | yes |
| site_id | ArcGIS Enterprise site Id | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| grafana_endpoint | Grafana endpoint |
| prometheus_query_endpoint | Prometheus query endpoint |
<!-- END_TF_DOCS -->