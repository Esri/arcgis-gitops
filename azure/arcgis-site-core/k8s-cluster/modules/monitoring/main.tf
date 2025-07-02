/**
 * # Terraform module monitoring
 * 
 * The module deploys Monitoring subsystem that include Azure Monitor workspace and Azure Managed Grafana instances.
 *
 * 1. Creates Azure Monitor Workspace.
 * 2. Create data collection rule associations (DCRAs) for the AKS cluster and the default data collection rule of the monitor workspace.
 * 3. Create Azure Managed Grafana instance.
 * 4. Assign Grafana dashboard identity "Monitoring Data Reader" role to read data from the Azure Monitor Workspace.
 * 5. Creates Prometheus rule groups with default recording rules. 
 *
 * See: https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/quickstart-deploy-application-gateway-for-containers-alb-controller
 */

# Copyright 2024-2025 Esri
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

# Monitoring subsystem for Azure Kubernetes Service (AKS)
# See https://learn.microsoft.com/en-us/azure/aks/monitor-aks

data "azurerm_kubernetes_cluster" "site_cluster" {
  name                = var.cluster_name
  resource_group_name = var.resource_group_name
}

# Azure Monitor workspace (Managed Prometheus)
resource "azurerm_monitor_workspace" "prometheus" {
  name                          = var.site_id
  resource_group_name           = var.resource_group_name
  location                      = var.azure_region
  public_network_access_enabled = true

  tags = {
    ArcGISSiteId = var.site_id
  }
}

# Create data collection rule associations (DCRAs) for the AKS cluster and the default data collection rule of the monitor workspace.
resource "azurerm_monitor_data_collection_rule_association" "dcra" {
  name                    = "MSProm-${var.azure_region}-${var.cluster_name}"
  target_resource_id      = data.azurerm_kubernetes_cluster.site_cluster.id
  data_collection_rule_id = azurerm_monitor_workspace.prometheus.default_data_collection_rule_id
  description             = "Association of data collection rule. Deleting this association will break the data collection for this AKS Cluster."
}

# Create azure private endpoint for the monitor workspace data collection endpoint.
# See https://learn.microsoft.com/en-us/azure/azure-monitor/logs/private-link-security

# resource "azurerm_private_dns_zone" "prometheus_private_dns_zone" {
#   count               = length(local.private_dns_zones)
#   name                = local.private_dns_zones[count.index]
#   resource_group_name = azurerm_resource_group.cluster_rg.name
# }

# resource "azurerm_private_dns_zone_virtual_network_link" "prometheus_private_dns_zone_virtual_network_link" {
#   count                 = length(local.private_dns_zones)
#   name                  = local.private_dns_zones[count.index]
#   private_dns_zone_name = local.private_dns_zones[count.index]
#   resource_group_name   = azurerm_resource_group.cluster_rg.name
#   virtual_network_id    = module.site_core_info.vnet_id

#   depends_on = [
#     azurerm_private_dns_zone.prometheus_private_dns_zone
#   ]
# }

# resource "azurerm_private_endpoint" "prometheus_amsl" {
#   name                = "${azurerm_monitor_workspace.prometheus.name}-prometheus-private-endpoint"
#   resource_group_name = azurerm_resource_group.cluster_rg.name
#   location            = azurerm_resource_group.cluster_rg.location
#   subnet_id           = module.site_core_info.internal_subnets[0]

#   private_service_connection {
#     name                           = "${azurerm_monitor_workspace.prometheus.name}-psc"
#     private_connection_resource_id = azurerm_monitor_private_link_scope.ampls.id
#     is_manual_connection           = false
#     subresource_names = [
#       "azuremonitor"
#     ]
#   }

#   private_dns_zone_group {
#     name                 = "default"
#     private_dns_zone_ids = azurerm_private_dns_zone.prometheus_private_dns_zone.*.id
#   }

#   tags = {
#     ArcGISSiteId = var.site_id
#   }

#   depends_on = [ 
#     azurerm_private_dns_zone.prometheus_private_dns_zone,
#     azurerm_private_dns_zone_virtual_network_link.prometheus_private_dns_zone_virtual_network_link
#   ]
# }

# # Azure Monitor private links are structured differently from private links to
# # other services you might use. Instead of creating multiple private links, 
# # one for each resource the virtual network connects to, Azure Monitor uses a 
# # single private link connection, from the virtual network to an AMPLS. 
# # AMPLS is the set of all Azure Monitor resources to which a virtual network 
# # connects through a private link.
# resource "azurerm_monitor_private_link_scope" "ampls" {
#   name                = var.site_id
#   resource_group_name = azurerm_resource_group.cluster_rg.name

#   ingestion_access_mode = "Open"
#   query_access_mode     = "Open"
# }

# resource "azurerm_monitor_private_link_scoped_service" "default_dce" {
#   name                = "${var.site_id}-default-dce"
#   resource_group_name = azurerm_resource_group.cluster_rg.name
#   scope_name          = azurerm_monitor_private_link_scope.ampls.name
#   # linked_resource_id  = azurerm_monitor_data_collection_endpoint.dce.id
#   linked_resource_id = azurerm_monitor_workspace.prometheus.default_data_collection_endpoint_id
# }

# Create Azure Managed Grafana instance
resource "azurerm_dashboard_grafana" "grafana" {
  name                              = var.site_id
  resource_group_name               = var.resource_group_name
  location                          = var.azure_region
  grafana_major_version             = var.grafana_major_version
  api_key_enabled                   = true
  deterministic_outbound_ip_enabled = true
  public_network_access_enabled     = true
  sku                               = "Standard"

  identity {
    type = "SystemAssigned"
  }

  azure_monitor_workspace_integrations {
    resource_id = azurerm_monitor_workspace.prometheus.id
  }

  tags = {
    ArcGISSiteId = var.site_id
  }
}

# Assign Grafana dashboard identity "Monitoring Data Reader" role to read data from the Azure Monitor Workspace.
resource "azurerm_role_assignment" "data_reader_role" {
  scope              = azurerm_monitor_workspace.prometheus.id
  role_definition_id = "/subscriptions/${split("/", azurerm_monitor_workspace.prometheus.id)[2]}/providers/Microsoft.Authorization/roleDefinitions/b0d8363b-8ddd-447d-831f-62ca05bff136"
  principal_id       = azurerm_dashboard_grafana.grafana.identity[0].principal_id
}

# The following default recording rules are automatically configured by Azure Monitor managed service for Prometheus 
# when you configure Prometheus metrics to be scraped from an Azure Kubernetes Service (AKS) cluster. 
# See https://learn.microsoft.com/en-us/azure/azure-monitor/containers/prometheus-metrics-scrape-default

resource "azurerm_monitor_alert_prometheus_rule_group" "node_recording_rules_rule_group" {
  name                = "NodeRecordingRulesRuleGroup - ${var.cluster_name}"
  location            = var.azure_region
  resource_group_name = var.resource_group_name
  cluster_name        = var.cluster_name
  description         = "Node Recording Rules Rule Group"
  rule_group_enabled  = true
  interval            = "PT1M"
  scopes              = [azurerm_monitor_workspace.prometheus.id, data.azurerm_kubernetes_cluster.site_cluster.id]

  rule {
    enabled    = true
    record     = "instance:node_num_cpu:sum"
    expression = <<EOF
count without (cpu, mode) (node_cpu_seconds_total{job="node",mode="idle"})
EOF
  }
  rule {
    enabled    = true
    record     = "instance:node_cpu_utilisation:rate5m"
    expression = <<EOF
1 - avg without (cpu) (sum without (mode) (rate(node_cpu_seconds_total{job="node", mode=~"idle|iowait|steal"}[5m])))
EOF
  }
  rule {
    enabled    = true
    record     = "instance:node_load1_per_cpu:ratio"
    expression = <<EOF
(node_load1{job="node"}/ instance:node_num_cpu:sum{job="node"})
EOF
  }
  rule {
    enabled    = true
    record     = "instance:node_memory_utilisation:ratio"
    expression = <<EOF
1 - ((node_memory_MemAvailable_bytes{job="node"} or (node_memory_Buffers_bytes{job="node"} + node_memory_Cached_bytes{job="node"}      +      node_memory_MemFree_bytes{job="node"} + node_memory_Slab_bytes{job="node"}))/ node_memory_MemTotal_bytes{job="node"})
EOF
  }
  rule {
    enabled    = true
    record     = "instance:node_vmstat_pgmajfault:rate5m"
    expression = <<EOF
rate(node_vmstat_pgmajfault{job="node"}[5m])
EOF
  }
  rule {
    enabled    = true
    record     = "instance_device:node_disk_io_time_seconds:rate5m"
    expression = <<EOF
rate(node_disk_io_time_seconds_total{job="node", device!=""}[5m])
EOF
  }
  rule {
    enabled    = true
    record     = "instance_device:node_disk_io_time_weighted_seconds:rate5m"
    expression = <<EOF
rate(node_disk_io_time_weighted_seconds_total{job="node", device!=""}[5m])
EOF
  }
  rule {
    enabled    = true
    record     = "instance:node_network_receive_bytes_excluding_lo:rate5m"
    expression = <<EOF
sum without (device) (rate(node_network_receive_bytes_total{job="node", device!="lo"}[5m]))
EOF
  }
  rule {
    enabled    = true
    record     = "instance:node_network_transmit_bytes_excluding_lo:rate5m"
    expression = <<EOF
sum without (device) (rate(node_network_transmit_bytes_total{job="node", device!="lo"}[5m]))
EOF
  }
  rule {
    enabled    = true
    record     = "instance:node_network_receive_drop_excluding_lo:rate5m"
    expression = <<EOF
sum without (device) (rate(node_network_receive_drop_total{job="node", device!="lo"}[5m]))
EOF
  }
  rule {
    enabled    = true
    record     = "instance:node_network_transmit_drop_excluding_lo:rate5m"
    expression = <<EOF
sum without (device) (rate(node_network_transmit_drop_total{job="node", device!="lo"}[5m]))
EOF
  }
}

resource "azurerm_monitor_alert_prometheus_rule_group" "kubernetes_recording_rules_rule_group" {
  name                = "KubernetesRecordingRulesRuleGroup - ${var.cluster_name}"
  location            = var.azure_region
  resource_group_name = var.resource_group_name
  cluster_name        = var.cluster_name
  description         = "Kubernetes Recording Rules Rule Group"
  rule_group_enabled  = true
  interval            = "PT1M"
  scopes              = [azurerm_monitor_workspace.prometheus.id, data.azurerm_kubernetes_cluster.site_cluster.id]

  rule {
    enabled    = true
    record     = "node_namespace_pod_container:container_cpu_usage_seconds_total:sum_irate"
    expression = <<EOF
sum by (cluster, namespace, pod, container) (irate(container_cpu_usage_seconds_total{job="cadvisor", image!=""}[5m])) * on (cluster, namespace, pod) group_left(node) topk by (cluster, namespace, pod) (1, max by(cluster, namespace, pod, node) (kube_pod_info{node!=""}))
EOF
  }
  rule {
    enabled    = true
    record     = "node_namespace_pod_container:container_memory_working_set_bytes"
    expression = <<EOF
container_memory_working_set_bytes{job="cadvisor", image!=""}* on (namespace, pod) group_left(node) topk by(namespace, pod) (1,  max by(namespace, pod, node) (kube_pod_info{node!=""}))
EOF
  }
  rule {
    enabled    = true
    record     = "node_namespace_pod_container:container_memory_rss"
    expression = <<EOF
container_memory_rss{job="cadvisor", image!=""}* on (namespace, pod) group_left(node) topk by(namespace, pod) (1,  max by(namespace, pod, node) (kube_pod_info{node!=""}))
EOF
  }
  rule {
    enabled    = true
    record     = "node_namespace_pod_container:container_memory_cache"
    expression = <<EOF
container_memory_cache{job="cadvisor", image!=""}* on (namespace, pod) group_left(node) topk by(namespace, pod) (1,  max by(namespace, pod, node) (kube_pod_info{node!=""}))
EOF
  }
  rule {
    enabled    = true
    record     = "node_namespace_pod_container:container_memory_swap"
    expression = <<EOF
container_memory_swap{job="cadvisor", image!=""}* on (namespace, pod) group_left(node) topk by(namespace, pod) (1,  max by(namespace, pod, node) (kube_pod_info{node!=""}))
EOF
  }
  rule {
    enabled    = true
    record     = "cluster:namespace:pod_memory:active:kube_pod_container_resource_requests"
    expression = <<EOF
kube_pod_container_resource_requests{resource="memory",job="kube-state-metrics"}  * on (namespace, pod, cluster)group_left() max by (namespace, pod, cluster) (  (kube_pod_status_phase{phase=~"Pending|Running"} == 1))
EOF
  }
  rule {
    enabled    = true
    record     = "namespace_memory:kube_pod_container_resource_requests:sum"
    expression = <<EOF
sum by (namespace, cluster) (sum by (namespace, pod, cluster) (max by (namespace, pod, container, cluster) (kube_pod_container_resource_requests{resource="memory",job="kube-state-metrics"}) * on(namespace, pod, cluster) group_left() max by (namespace, pod, cluster) (kube_pod_status_phase{phase=~"Pending|Running"} == 1 )))
EOF
  }
  rule {
    enabled    = true
    record     = "cluster:namespace:pod_cpu:active:kube_pod_container_resource_requests"
    expression = <<EOF
kube_pod_container_resource_requests{resource="cpu",job="kube-state-metrics"}  * on (namespace, pod, cluster)group_left() max by (namespace, pod, cluster) ((kube_pod_status_phase{phase=~"Pending|Running"} == 1))
EOF
  }
  rule {
    enabled    = true
    record     = "namespace_cpu:kube_pod_container_resource_requests:sum"
    expression = <<EOF
sum by (namespace, cluster) (sum by (namespace, pod, cluster) (max by (namespace, pod, container, cluster) (          kube_pod_container_resource_requests{resource="cpu",job="kube-state-metrics"}        ) * on(namespace, pod, cluster) group_left() max by (namespace, pod, cluster) (kube_pod_status_phase{phase=~"Pending|Running"} == 1 )))
EOF
  }
  rule {
    enabled    = true
    record     = "cluster:namespace:pod_memory:active:kube_pod_container_resource_limits"
    expression = <<EOF
kube_pod_container_resource_limits{resource="memory",job="kube-state-metrics"}  * on (namespace, pod, cluster)group_left() max by (namespace, pod, cluster) ((kube_pod_status_phase{phase=~"Pending|Running"} == 1))
EOF
  }
  rule {
    enabled    = true
    record     = "namespace_memory:kube_pod_container_resource_limits:sum"
    expression = <<EOF
sum by (namespace, cluster) (sum by (namespace, pod, cluster) (max by (namespace, pod, container, cluster) (kube_pod_container_resource_limits{resource="memory",job="kube-state-metrics"}) * on(namespace, pod, cluster) group_left() max by (namespace, pod, cluster) (kube_pod_status_phase{phase=~"Pending|Running"} == 1)))
EOF
  }
  rule {
    enabled    = true
    record     = "cluster:namespace:pod_cpu:active:kube_pod_container_resource_limits"
    expression = <<EOF
kube_pod_container_resource_limits{resource="cpu",job="kube-state-metrics"}  * on (namespace, pod, cluster)group_left() max by (namespace, pod, cluster) ((kube_pod_status_phase{phase=~"Pending|Running"} == 1))
EOF
  }
  rule {
    enabled    = true
    record     = "namespace_cpu:kube_pod_container_resource_limits:sum"
    expression = <<EOF
sum by (namespace, cluster) (sum by (namespace, pod, cluster) (max by (namespace, pod, container, cluster) (kube_pod_container_resource_limits{resource="cpu",job="kube-state-metrics"}) * on(namespace, pod, cluster) group_left() max by (namespace, pod, cluster) (kube_pod_status_phase{phase=~"Pending|Running"} == 1)))
EOF
  }
  rule {
    enabled    = true
    record     = "namespace_workload_pod:kube_pod_owner:relabel"
    expression = <<EOF
max by (cluster, namespace, workload, pod) (label_replace(label_replace(kube_pod_owner{job="kube-state-metrics", owner_kind="ReplicaSet"}, "replicaset", "$1", "owner_name", "(.*)") * on(replicaset, namespace) group_left(owner_name) topk by(replicaset, namespace) (1, max by (replicaset, namespace, owner_name) (kube_replicaset_owner{job="kube-state-metrics"})), "workload", "$1", "owner_name", "(.*)" ))
EOF
    labels = {
      workload_type = "deployment"
    }
  }
  rule {
    enabled    = true
    record     = "namespace_workload_pod:kube_pod_owner:relabel"
    expression = <<EOF
max by (cluster, namespace, workload, pod) (label_replace(kube_pod_owner{job="kube-state-metrics", owner_kind="DaemonSet"}, "workload", "$1", "owner_name", "(.*)" ))
EOF
    labels = {
      workload_type = "daemonset"
    }
  }
  rule {
    enabled    = true
    record     = "namespace_workload_pod:kube_pod_owner:relabel"
    expression = <<EOF
max by (cluster, namespace, workload, pod) (label_replace(kube_pod_owner{job="kube-state-metrics", owner_kind="StatefulSet"}, "workload", "$1", "owner_name", "(.*)" ))
EOF
    labels = {
      workload_type = "statefulset"
    }
  }
  rule {
    enabled    = true
    record     = "namespace_workload_pod:kube_pod_owner:relabel"
    expression = <<EOF
max by (cluster, namespace, workload, pod) (label_replace(kube_pod_owner{job="kube-state-metrics", owner_kind="Job"}, "workload", "$1", "owner_name", "(.*)" ))
EOF
    labels = {
      workload_type = "job"
    }
  }
  rule {
    enabled    = true
    record     = ":node_memory_MemAvailable_bytes:sum"
    expression = <<EOF
sum(node_memory_MemAvailable_bytes{job="node"} or (node_memory_Buffers_bytes{job="node"} + node_memory_Cached_bytes{job="node"} + node_memory_MemFree_bytes{job="node"} + node_memory_Slab_bytes{job="node"} )) by (cluster)
EOF
  }
  rule {
    enabled    = true
    record     = "cluster:node_cpu:ratio_rate5m"
    expression = <<EOF
sum(rate(node_cpu_seconds_total{job="node",mode!="idle",mode!="iowait",mode!="steal"}[5m])) by (cluster) /count(sum(node_cpu_seconds_total{job="node"}) by (cluster, instance, cpu)) by (cluster)
EOF
  }
}

resource "azurerm_monitor_alert_prometheus_rule_group" "ux_recording_rules_rule_group" {
  name                = "UXRecordingRulesRuleGroup - ${var.cluster_name}"
  location            = var.azure_region
  resource_group_name = var.resource_group_name
  cluster_name        = var.cluster_name
  description         = "UX Recording Rules for Linux"
  rule_group_enabled  = true
  interval            = "PT1M"
  scopes              = [azurerm_monitor_workspace.prometheus.id, data.azurerm_kubernetes_cluster.site_cluster.id]

  rule {
    enabled    = true
    record     = "ux:pod_cpu_usage:sum_irate"
    expression = "(sum by (namespace, pod, cluster, microsoft_resourceid) (\n\tirate(container_cpu_usage_seconds_total{container != \"\", pod != \"\", job = \"cadvisor\"}[5m])\n)) * on (pod, namespace, cluster, microsoft_resourceid) group_left (node, created_by_name, created_by_kind)\n(max by (node, created_by_name, created_by_kind, pod, namespace, cluster, microsoft_resourceid) (kube_pod_info{pod != \"\", job = \"kube-state-metrics\"}))"
  }

  rule {
    enabled    = true
    record     = "ux:controller_cpu_usage:sum_irate"
    expression = "sum by (namespace, node, cluster, created_by_name, created_by_kind, microsoft_resourceid) (\nux:pod_cpu_usage:sum_irate\n)\n"
  }

  rule {
    enabled    = true
    record     = "ux:pod_workingset_memory:sum"
    expression = "(sum by (namespace, pod, cluster, microsoft_resourceid) (\n\t\tcontainer_memory_working_set_bytes{container != \"\", pod != \"\", job = \"cadvisor\"}\n\t    )\n\t) * on (pod, namespace, cluster, microsoft_resourceid) group_left (node, created_by_name, created_by_kind)\n(max by (node, created_by_name, created_by_kind, pod, namespace, cluster, microsoft_resourceid) (kube_pod_info{pod != \"\", job = \"kube-state-metrics\"}))"
  }

  rule {
    enabled    = true
    record     = "ux:controller_workingset_memory:sum"
    expression = "sum by (namespace, node, cluster, created_by_name, created_by_kind, microsoft_resourceid) (\nux:pod_workingset_memory:sum\n)"
  }

  rule {
    enabled    = true
    record     = "ux:pod_rss_memory:sum"
    expression = "(sum by (namespace, pod, cluster, microsoft_resourceid) (\n\t\tcontainer_memory_rss{container != \"\", pod != \"\", job = \"cadvisor\"}\n\t    )\n\t) * on (pod, namespace, cluster, microsoft_resourceid) group_left (node, created_by_name, created_by_kind)\n(max by (node, created_by_name, created_by_kind, pod, namespace, cluster, microsoft_resourceid) (kube_pod_info{pod != \"\", job = \"kube-state-metrics\"}))"
  }

  rule {
    enabled    = true
    record     = "ux:controller_rss_memory:sum"
    expression = "sum by (namespace, node, cluster, created_by_name, created_by_kind, microsoft_resourceid) (\nux:pod_rss_memory:sum\n)"
  }

  rule {
    enabled    = true
    record     = "ux:pod_container_count:sum"
    expression = "sum by (node, created_by_name, created_by_kind, namespace, cluster, pod, microsoft_resourceid) (\n(\n(\nsum by (container, pod, namespace, cluster, microsoft_resourceid) (kube_pod_container_info{container != \"\", pod != \"\", container_id != \"\", job = \"kube-state-metrics\"})\nor sum by (container, pod, namespace, cluster, microsoft_resourceid) (kube_pod_init_container_info{container != \"\", pod != \"\", container_id != \"\", job = \"kube-state-metrics\"})\n)\n* on (pod, namespace, cluster, microsoft_resourceid) group_left (node, created_by_name, created_by_kind)\n(\nmax by (node, created_by_name, created_by_kind, pod, namespace, cluster, microsoft_resourceid) (\n\tkube_pod_info{pod != \"\", job = \"kube-state-metrics\"}\n)\n)\n)\n\n)"
  }

  rule {
    enabled    = true
    record     = "ux:controller_container_count:sum"
    expression = "sum by (node, created_by_name, created_by_kind, namespace, cluster, microsoft_resourceid) (\nux:pod_container_count:sum\n)"
  }

  rule {
    enabled    = true
    record     = "ux:pod_container_restarts:max"
    expression = "max by (node, created_by_name, created_by_kind, namespace, cluster, pod, microsoft_resourceid) (\n(\n(\nmax by (container, pod, namespace, cluster, microsoft_resourceid) (kube_pod_container_status_restarts_total{container != \"\", pod != \"\", job = \"kube-state-metrics\"})\nor sum by (container, pod, namespace, cluster, microsoft_resourceid) (kube_pod_init_status_restarts_total{container != \"\", pod != \"\", job = \"kube-state-metrics\"})\n)\n* on (pod, namespace, cluster, microsoft_resourceid) group_left (node, created_by_name, created_by_kind)\n(\nmax by (node, created_by_name, created_by_kind, pod, namespace, cluster, microsoft_resourceid) (\n\tkube_pod_info{pod != \"\", job = \"kube-state-metrics\"}\n)\n)\n)\n\n)"
  }

  rule {
    enabled    = true
    record     = "ux:controller_container_restarts:max"
    expression = "max by (node, created_by_name, created_by_kind, namespace, cluster, microsoft_resourceid) (\nux:pod_container_restarts:max\n)"
  }

  rule {
    enabled    = true
    record     = "ux:pod_resource_limit:sum"
    expression = "(sum by (cluster, pod, namespace, resource, microsoft_resourceid) (\n(\n\tmax by (cluster, microsoft_resourceid, pod, container, namespace, resource)\n\t (kube_pod_container_resource_limits{container != \"\", pod != \"\", job = \"kube-state-metrics\"})\n)\n)unless (count by (pod, namespace, cluster, resource, microsoft_resourceid)\n\t(kube_pod_container_resource_limits{container != \"\", pod != \"\", job = \"kube-state-metrics\"})\n!= on (pod, namespace, cluster, microsoft_resourceid) group_left()\n sum by (pod, namespace, cluster, microsoft_resourceid)\n (kube_pod_container_info{container != \"\", pod != \"\", job = \"kube-state-metrics\"}) \n)\n\n)* on (namespace, pod, cluster, microsoft_resourceid) group_left (node, created_by_kind, created_by_name)\n(\n\tkube_pod_info{pod != \"\", job = \"kube-state-metrics\"}\n)"
  }

  rule {
    enabled    = true
    record     = "ux:controller_resource_limit:sum"
    expression = "sum by (cluster, namespace, created_by_name, created_by_kind, node, resource, microsoft_resourceid) (\nux:pod_resource_limit:sum\n)"
  }

  rule {
    enabled    = true
    record     = "ux:controller_pod_phase_count:sum"
    expression = "sum by (cluster, phase, node, created_by_kind, created_by_name, namespace, microsoft_resourceid) ( (\n(kube_pod_status_phase{job=\"kube-state-metrics\",pod!=\"\"})\n or (label_replace((count(kube_pod_deletion_timestamp{job=\"kube-state-metrics\",pod!=\"\"}) by (namespace, pod, cluster, microsoft_resourceid) * count(kube_pod_status_reason{reason=\"NodeLost\", job=\"kube-state-metrics\"} == 0) by (namespace, pod, cluster, microsoft_resourceid)), \"phase\", \"terminating\", \"\", \"\"))) * on (pod, namespace, cluster, microsoft_resourceid) group_left (node, created_by_name, created_by_kind)\n(\nmax by (node, created_by_name, created_by_kind, pod, namespace, cluster, microsoft_resourceid) (\nkube_pod_info{job=\"kube-state-metrics\",pod!=\"\"}\n)\n)\n)"
  }

  rule {
    enabled    = true
    record     = "ux:cluster_pod_phase_count:sum"
    expression = "sum by (cluster, phase, node, namespace, microsoft_resourceid) (\nux:controller_pod_phase_count:sum\n)"
  }

  rule {
    enabled    = true
    record     = "ux:node_cpu_usage:sum_irate"
    expression = "sum by (instance, cluster, microsoft_resourceid) (\n(1 - irate(node_cpu_seconds_total{job=\"node\", mode=\"idle\"}[5m]))\n)"
  }

  rule {
    enabled    = true
    record     = "ux:node_memory_usage:sum"
    expression = "sum by (instance, cluster, microsoft_resourceid) ((\nnode_memory_MemTotal_bytes{job = \"node\"}\n- node_memory_MemFree_bytes{job = \"node\"} \n- node_memory_cached_bytes{job = \"node\"}\n- node_memory_buffers_bytes{job = \"node\"}\n))"
  }

  rule {
    enabled    = true
    record     = "ux:node_network_receive_drop_total:sum_irate"
    expression = "sum by (instance, cluster, microsoft_resourceid) (irate(node_network_receive_drop_total{job=\"node\", device!=\"lo\"}[5m]))"
  }

  rule {
    enabled    = true
    record     = "ux:node_network_transmit_drop_total:sum_irate"
    expression = "sum by (instance, cluster, microsoft_resourceid) (irate(node_network_transmit_drop_total{job=\"node\", device!=\"lo\"}[5m]))"
  }
}

