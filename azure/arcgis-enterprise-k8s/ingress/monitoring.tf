# Copyright 2026 Esri
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

data "azurerm_key_vault_secret" "site_alerts_action_group_id" {
  name         = "site-alerts-action-group-id"
  key_vault_id = module.site_core_info.vault_id
}

resource "azurerm_log_analytics_workspace" "ingress" {
  name                = azurerm_application_load_balancer.ingress.name
  location            = azurerm_resource_group.deployment_rg.location
  resource_group_name = azurerm_resource_group.deployment_rg.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention

  tags = {
    ArcGISSiteId       = var.site_id
    ArcGISDeploymentId = var.deployment_id
  }
}

resource "azurerm_monitor_diagnostic_setting" "app_gateway_logs" {
  name                       = "${azurerm_application_load_balancer.ingress.name}-diagnostic-settings"
  target_resource_id         = azurerm_application_load_balancer.ingress.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.ingress.id

  dynamic "enabled_log" {
    for_each = var.enabled_log_categories

    content {
      category = enabled_log.value
    }
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_metric_alert" "backend_healthy_targets" {
  name                = "BackendHealthyTargetsAlert"
  resource_group_name = azurerm_resource_group.deployment_rg.name
  scopes              = [azurerm_application_load_balancer.ingress.id]
  description         = "Action will be triggered when Application Gateway for Containers BackendHealthyTargets metric is equal to 0."
  severity            = 0 # Critical

  criteria {
    metric_namespace = "microsoft.servicenetworking/trafficcontrollers"
    metric_name      = "BackendHealthyTargets"
    aggregation      = "Average"
    operator         = "Equals"
    threshold        = 0
  }

  action {
    action_group_id = data.azurerm_key_vault_secret.site_alerts_action_group_id.value
  }

  tags = {
    ArcGISSiteId       = var.site_id
    ArcGISDeploymentId = var.deployment_id
  }
}

# Ingress Dashboard
resource "azurerm_portal_dashboard" "ingress" {
  name                = "${azurerm_application_load_balancer.ingress.name}-ingress"
  resource_group_name = azurerm_resource_group.deployment_rg.name
  location            = azurerm_resource_group.deployment_rg.location
  dashboard_properties = jsonencode({
    lenses = {
      "0" = {
        order = 0
        parts = {
          "0" = { // Total Requests 
            metadata = {
              inputs = [{
                isOptional = true
                name       = "options"
                value = {
                  chart = {
                    metrics = [{
                      aggregationType = 1
                      metricVisualization = {
                        displayName = "Total Requests"
                        color = "#5e7af2"
                      }
                      name      = "TotalRequests"
                      namespace = "microsoft.servicenetworking/trafficcontrollers"
                      resourceMetadata = {
                        id = azurerm_application_load_balancer.ingress.id
                      }
                    }]
                    timespan = {
                      grain = 1
                      relative = {
                        duration = 86400000
                      }
                      showUTCTime = false
                    }
                    title     = "Total Requests Count"
                    titleKind = 1
                    visualization = {
                      axisVisualization = {
                        x = {
                          axisType  = 2
                          isVisible = true
                        }
                        y = {
                          axisType  = 1
                          isVisible = true
                        }
                      }
                      chartType = 2
                      legendVisualization = {
                        hideHoverCard  = false
                        hideLabelNames = true
                        isVisible      = true
                        position       = 2
                      }
                    }
                  }
                }
                },
                {
                  isOptional = true
                  name       = "sharedTimeRange"
                }
              ]
              settings = {
                content = {
                  options = {
                    chart = {
                      metrics = [{
                        aggregationType = 1
                        metricVisualization = {
                          displayName = "Total Requests"
                          color = "#5e7af2"
                        }
                        name      = "TotalRequests"
                        namespace = "microsoft.servicenetworking/trafficcontrollers"
                        resourceMetadata = {
                          id = azurerm_application_load_balancer.ingress.id
                        }
                      }]
                      title     = "Total Requests Count"
                      titleKind = 1
                      visualization = {
                        axisVisualization = {
                          x = {
                            axisType  = 2
                            isVisible = true
                          }
                          y = {
                            axisType  = 1
                            isVisible = true
                          }
                        }
                        chartType      = 2
                        disablePinning = true
                        legendVisualization = {
                          hideHoverCard  = false
                          hideLabelNames = true
                          isVisible      = true
                          position       = 2
                        }
                      }
                    }
                  }
                }
              }
              type = "Extension/HubsExtension/PartType/MonitorChartPart"
            }
            position = {
              colSpan = 6
              rowSpan = 4
              x       = 0
              y       = 0
            }
          }
          "1" = { // Failed Requests
            metadata = {
              inputs = [{
                isOptional = true
                name       = "options"
                value = {
                  chart = {
                    metrics = [{
                      aggregationType = 1
                      metricVisualization = {
                        displayName = "Failed Requests"
                        color = "#f06298"
                      }
                      name      = "HTTPResponseStatus"
                      namespace = "microsoft.servicenetworking/trafficcontrollers"
                      resourceMetadata = {
                        id = azurerm_application_load_balancer.ingress.id
                      }
                    }]
                    filterCollection = {
                      filters = [
                        {
                          key      = "HttpResponseCode"
                          operator = 0
                          values = [
                            "5xx"
                          ]
                        }
                      ]
                    }
                    timespan = {
                      grain = 1
                      relative = {
                        duration = 86400000
                      }
                      showUTCTime = false
                    }
                    title     = "Failed Requests Count"
                    titleKind = 1
                    visualization = {
                      axisVisualization = {
                        x = {
                          axisType  = 2
                          isVisible = true
                        }
                        y = {
                          axisType  = 1
                          isVisible = true
                        }
                      }
                      chartType = 2
                      legendVisualization = {
                        hideHoverCard  = false
                        hideLabelNames = true
                        isVisible      = true
                        position       = 2
                      }
                    }
                  }
                }
                },
                {
                  isOptional = true
                  name       = "sharedTimeRange"
                }
              ]
              settings = {
                content = {
                  options = {
                    chart = {
                      metrics = [{
                        aggregationType = 1
                        metricVisualization = {
                          displayName = "Failed Requests"
                          color = "#f06298"
                        }
                        name      = "HTTPResponseStatus"
                        namespace = "microsoft.servicenetworking/trafficcontrollers"
                        resourceMetadata = {
                          id = azurerm_application_load_balancer.ingress.id
                        }
                      }]
                      title     = "Failed Requests Count"
                      titleKind = 1
                      visualization = {
                        axisVisualization = {
                          x = {
                            axisType  = 2
                            isVisible = true
                          }
                          y = {
                            axisType  = 1
                            isVisible = true
                          }
                        }
                        chartType      = 2
                        disablePinning = true
                        legendVisualization = {
                          hideHoverCard  = false
                          hideLabelNames = true
                          isVisible      = true
                          position       = 2
                        }
                      }
                      filterCollection = {
                        filters = [
                          {
                            key      = "HttpResponseCode"
                            operator = 0
                            values = [
                              "5xx"
                            ]
                          }
                        ]
                      }
                    }
                  }
                }
              }
              type = "Extension/HubsExtension/PartType/MonitorChartPart"
            }
            position = {
              colSpan = 6
              rowSpan = 4
              x       = 6
              y       = 0
            }
          }
          "2" = { // Backend Healthy Targets
            metadata = {
              inputs = [{
                isOptional = true
                name       = "options"
                }, {
                isOptional = true
                name       = "sharedTimeRange"
              }]
              settings = {
                content = {
                  options = {
                    chart = {
                      metrics = [{
                        aggregationType = 4
                        metricVisualization = {
                          displayName = "Backend Healthy Targets"
                          color = "#5e7af2"
                        }
                        name      = "BackendHealthyTargets"
                        namespace = "microsoft.servicenetworking/trafficcontrollers"
                        resourceMetadata = {
                          id = azurerm_application_load_balancer.ingress.id
                        }
                      }]
                      title     = "Backend Healthy Targets"
                      titleKind = 1
                      visualization = {
                        axisVisualization = {
                          x = {
                            axisType  = 2
                            isVisible = true
                          }
                          y = {
                            axisType  = 1
                            isVisible = true
                          }
                        }
                        chartType      = 2
                        disablePinning = true
                        legendVisualization = {
                          hideHoverCard  = false
                          hideLabelNames = true
                          isVisible      = true
                          position       = 2
                        }
                      }
                    }
                  }
                }
              }
              type = "Extension/HubsExtension/PartType/MonitorChartPart"
            }
            position = {
              colSpan = 6
              rowSpan = 4
              x       = 0
              y       = 4
            }
          }
          "3" = {
            metadata = {
              inputs = [{
                isOptional = true
                name       = "options"
                value = {
                  chart = {
                    metrics = [{
                      aggregationType = 1
                      metricVisualization = {
                        displayName = "WAF Managed Rule Matches"
                        color = "#f06298"
                      }
                      name      = "AzwafSecRule"
                      namespace = "microsoft.servicenetworking/trafficcontrollers"
                      resourceMetadata = {
                        id = azurerm_application_load_balancer.ingress.id
                      }
                    }]
                    timespan = {
                      grain = 1
                      relative = {
                        duration = 86400000
                      }
                      showUTCTime = false
                    }
                    title     = "WAF Managed Rule Matches"
                    titleKind = 1
                    visualization = {
                      axisVisualization = {
                        x = {
                          axisType  = 2
                          isVisible = true
                        }
                        y = {
                          axisType  = 1
                          isVisible = true
                        }
                      }
                      chartType = 2
                      legendVisualization = {
                        hideHoverCard  = false
                        hideLabelNames = true
                        isVisible      = true
                        position       = 2
                      }
                    }
                  }
                }
                }, {
                isOptional = true
                name       = "sharedTimeRange"
              }]
              settings = {
                content = {
                  options = {
                    chart = {
                      metrics = [{
                        aggregationType = 1
                        metricVisualization = {
                          displayName = "WAF Managed Rule Matches"
                          color = "#f06298"
                        }
                        name      = "AzwafSecRule"
                        namespace = "microsoft.servicenetworking/trafficcontrollers"
                        resourceMetadata = {
                          id = azurerm_application_load_balancer.ingress.id
                        }
                      }]
                      title     = "WAF Managed Rule Matches"
                      titleKind = 1
                      visualization = {
                        axisVisualization = {
                          x = {
                            axisType  = 2
                            isVisible = true
                          }
                          y = {
                            axisType  = 1
                            isVisible = true
                          }
                        }
                        chartType      = 2
                        disablePinning = true
                        legendVisualization = {
                          hideHoverCard  = false
                          hideLabelNames = true
                          isVisible      = true
                          position       = 2
                        }
                      }
                    }
                  }
                }
              }
              type = "Extension/HubsExtension/PartType/MonitorChartPart"
            }
            position = {
              colSpan = 6
              rowSpan = 4
              x       = 6
              y       = 4
            }
          },
          "4" = { // Requests flagged by WAF
            metadata = {
              inputs = [
                {
                  isOptional = true
                  name       = "resourceTypeMode"
                  }, {
                  isOptional = true
                  name       = "ComponentId"
                  }, {
                  isOptional = true
                  name       = "Scope"
                  value = {
                    resourceIds = [
                      azurerm_application_load_balancer.ingress.id
                    ]
                  }
                },
                {
                  isOptional = true
                  name       = "Version"
                  value      = "2.0"
                },
                {
                  isOptional = true
                  name       = "TimeRange"
                  value      = "P1D"
                },
                {
                  isOptional = true
                  name       = "DashboardId"
                },
                {
                  isOptional = true
                  name       = "DraftRequestParameters"
                },
                {
                  isOptional = true
                  name       = "Query"
                  value      = "AGCFirewallLogs | project TimeGenerated, Action, ClientIp, RequestUri, RuleSetType, RuleId, Message | sort by TimeGenerated | take 100"
                },
                {
                  isOptional = true
                  name       = "ControlType"
                  value      = "AnalyticsGrid"
                },
                {
                  isOptional = true
                  name       = "SpecificChart"
                },
                {
                  isOptional = true
                  name       = "PartTitle"
                  value      = "Requests flagged by WAF"
                },
                {
                  isOptional = true
                  name       = "PartSubTitle"
                  value      = azurerm_application_load_balancer.ingress.name
                },
                {
                  isOptional = true
                  name       = "Dimensions"
                },
                {
                  isOptional = true
                  name       = "LegendOptions"
                },
                {
                  isOptional = true
                  name       = "IsQueryContainTimeRange"
                  value      = false
                }
              ]
              settings = {
                content = {
                  GridColumnsWidth = {
                    Listener = "100px"
                    Method   = "100px"
                    Path     = "400px"
                  }
                  PartTitle = "Requests flagged by WAF"
                }
              }
              type = "Extension/Microsoft_OperationsManagementSuite_Workspace/PartType/LogsDashboardPart"
            }
            position = {
              colSpan = 12
              rowSpan = 8
              x       = 0
              y       = 8
            }
          }
        }
      }
    }
  })

  tags = {
    ArcGISSiteId       = var.site_id
    ArcGISDeploymentId = var.deployment_id
  }
}
