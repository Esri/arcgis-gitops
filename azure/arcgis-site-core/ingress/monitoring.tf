# resource "random_uuid" "workbook_id" {}

# resource "azurerm_application_insights_workbook" "example" {
#   name                = random_uuid.workbook_id.result
#   resource_group_name = azurerm_resource_group.deployment_rg.name
#   location            = azurerm_resource_group.deployment_rg.location
#   display_name        = "${var.site_id}-${var.deployment_id}"

#   data_json = jsonencode({
#     version = "Notebook/1.0"
#     items = [{
#       type = 10
#       name = "Unhealthy Hosts"
#       content = {
#         chartId      = "UnhealthyHosts"
#         version      = "MetricsItem/2.0"
#         size         = 0
#         chartType    = 2
#         resourceType = "microsoft.network/applicationgateways"
#         metricScope  = 0
#         resourceIds = [
#           azurerm_application_gateway.ingress.id
#         ]
#         timeContext = {
#           durationMs = 3600000
#         }
#         metrics = [{
#           namespace   = "microsoft.network/applicationgateways",
#           metric      = "microsoft.network/applicationgateways--UnhealthyHostCount"
#           aggregation = 4
#           }, {
#           namespace   = "microsoft.network/applicationgateways",
#           metric      = "microsoft.network/applicationgateways--FailedRequests"
#           aggregation = 1
#         }]
#         gridSettings = {
#           rowLimit = 10000
#         }
#       }
#     }]
#     fallbackResourceIds = [
#       "azure monitor"
#     ]
#   })

#   tags = {
#     ArcGISSiteId       = var.site_id
#     ArcGISDeploymentId = var.deployment_id
#   }
# }

# resource "azurerm_monitor_action_group" "critical_alerts" {
#   name                = "CriticalAlertsAction"
#   resource_group_name = azurerm_resource_group.deployment_rg.name
#   short_name          = "p0action"


#   email_receiver {
#     name          = "sendtoadmin"
#     email_address = "<email@example.com>"
#   }
# }

# resource "azurerm_monitor_metric_alert" "unhealthy_host_count" {
#   name                = "UnhealthyHostCountAlert"
#   resource_group_name = azurerm_resource_group.deployment_rg.name
#   scopes              = [azurerm_application_gateway.ingress.id]
#   description         = "Action will be triggered when Unhealthy Host Count is greater than 0."

#   criteria {
#     metric_namespace = "microsoft.network/applicationgateways"
#     metric_name      = "UnhealthyHostCount"
#     aggregation      = "Average"
#     operator         = "GreaterThan"
#     threshold        = 0
#   }

#   action {
#     action_group_id = azurerm_monitor_action_group.critical_alerts.id
#   }
# }

resource "azurerm_log_analytics_workspace" "ingress" {
  name                = azurerm_application_gateway.ingress.name
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
  name                       = "${azurerm_application_gateway.ingress.name}-diagnostic-settings"
  target_resource_id         = azurerm_application_gateway.ingress.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.ingress.id

  enabled_log {
    category = "ApplicationGatewayAccessLog"
  }

  enabled_log {
    category = "ApplicationGatewayPerformanceLog"
  }

  enabled_log {
    category = "ApplicationGatewayFirewallLog"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

# Ingress Dashboard
resource "azurerm_portal_dashboard" "ingress" {
  name                = azurerm_application_gateway.ingress.name
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
                    grouping = {
                      dimension = "BackendSettingsPool"
                      sort      = 2
                      top       = 10
                    }
                    metrics = [{
                      aggregationType = 4
                      metricVisualization = {
                        displayName = "Total Requests"
                      }
                      name      = "TotalRequests"
                      namespace = "microsoft.network/applicationgateways"
                      resourceMetadata = {
                        id = azurerm_application_gateway.ingress.id
                      }
                    }]
                    timespan = {
                      grain = 1
                      relative = {
                        duration = 86400000
                      }
                      showUTCTime = false
                    }
                    title     = "Avg Total Requests by Endpoint"
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
                      grouping = {
                        dimension = "BackendSettingsPool"
                        sort      = 2
                        top       = 10
                      }
                      metrics = [{
                        aggregationType = 4
                        metricVisualization = {
                          displayName = "Total Requests"
                        }
                        name      = "TotalRequests"
                        namespace = "microsoft.network/applicationgateways"
                        resourceMetadata = {
                          id = azurerm_application_gateway.ingress.id
                        }
                      }]
                      title     = "Avg Total Requests Count by Endpoint"
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
                    grouping = {
                      dimension = "BackendSettingsPool"
                      sort      = 2
                      top       = 10
                    }
                    metrics = [{
                      aggregationType = 4
                      metricVisualization = {
                        displayName = "Failed Requests"
                      }
                      name      = "FailedRequests"
                      namespace = "microsoft.network/applicationgateways"
                      resourceMetadata = {
                        id = azurerm_application_gateway.ingress.id
                      }
                    }]
                    timespan = {
                      grain = 1
                      relative = {
                        duration = 86400000
                      }
                      showUTCTime = false
                    }
                    title     = "Avg Failed Requests Count by Endpoint"
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
                      grouping = {
                        dimension = "BackendSettingsPool"
                        sort      = 2
                        top       = 10
                      }
                      metrics = [{
                        aggregationType = 4
                        metricVisualization = {
                          displayName = "Failed Requests"
                        }
                        name      = "FailedRequests"
                        namespace = "microsoft.network/applicationgateways"
                        resourceMetadata = {
                          id = azurerm_application_gateway.ingress.id
                        }
                      }]
                      title     = "Avg Failed Requests by Endpoint"
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
              y       = 0
            }
          }
          "2" = { // Backend First Byte Response Time
            metadata = {
              inputs = [{
                isOptional = true
                name       = "options"
                value = {
                  chart = {
                    grouping = {
                      dimension = "BackendHttpSetting"
                      sort      = 2
                      top       = 10
                    }
                    metrics = [{
                      aggregationType = 4
                      metricVisualization = {
                        displayName = "Backend First Byte Response Time"
                      }
                      name      = "BackendFirstByteResponseTime"
                      namespace = "microsoft.network/applicationgateways"
                      resourceMetadata = {
                        id = azurerm_application_gateway.ingress.id
                      }
                    }]
                    timespan = {
                      grain = 1
                      relative = {
                        duration = 86400000
                      }
                      showUTCTime = false
                    }
                    title     = "Avg First Byte Response Time by Endpoint"
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
                      grouping = {
                        dimension = "BackendHttpSetting"
                        sort      = 2
                        top       = 10
                      }
                      metrics = [{
                        aggregationType = 4
                        metricVisualization = {
                          displayName = "Backend First Byte Response Time"
                        }
                        name      = "BackendFirstByteResponseTime"
                        namespace = "microsoft.network/applicationgateways"
                        resourceMetadata = {
                          id = azurerm_application_gateway.ingress.id
                        }
                      }]
                      title     = "Avg Backend First Byte Response Time by Endpoint"
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
                }, {
                isOptional = true
                name       = "sharedTimeRange"
              }]
              settings = {
                content = {
                  options = {
                    chart = {
                      grouping = {
                        dimension = "BackendHttpSetting"
                        sort      = 2
                        top       = 10
                      }
                      metrics = [{
                        aggregationType = 4
                        metricVisualization = {
                          displayName = "Backend Error Responses"
                        }
                        name      = "BackendResponseStatus"
                        namespace = "microsoft.network/applicationgateways"
                        resourceMetadata = {
                          id = azurerm_application_gateway.ingress.id
                        }
                      }]
                      filterCollection = {
                        filters = [{
                          key      = "HttpStatusGroup",
                          operator = 0,
                          values = [
                            "5xx",
                            "4xx"
                          ]
                        }]
                      },
                      title     = "Backend Avg Error Responses Count by Endpoint"
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
          }
          "4" = {
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
                      grouping = {
                        dimension = "BackendSettingsPool"
                        sort      = 2
                        top       = 10
                      }
                      metrics = [{
                        aggregationType = 4
                        metricVisualization = {
                          displayName = "Healthy Host Count"
                        }
                        name      = "HealthyHostCount"
                        namespace = "microsoft.network/applicationgateways"
                        resourceMetadata = {
                          id = azurerm_application_gateway.ingress.id
                        }
                      }]
                      title     = "Avg Healthy Host Count by Endpoint"
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
              y       = 8
            }
          }
          "5" = {
            metadata = {
              inputs = [{
                isOptional = true
                name       = "options"
                value = {
                  chart = {
                    grouping = {
                      dimension = "BackendSettingsPool"
                      sort      = 2
                      top       = 10
                    }
                    metrics = [{
                      aggregationType = 4
                      metricVisualization = {
                        displayName = "Unhealthy Host Count"
                      }
                      name      = "UnhealthyHostCount"
                      namespace = "microsoft.network/applicationgateways"
                      resourceMetadata = {
                        id = azurerm_application_gateway.ingress.id
                      }
                    }]
                    timespan = {
                      grain = 1
                      relative = {
                        duration = 86400000
                      }
                      showUTCTime = false
                    }
                    title     = "Avg Unhealthy Host Count by Endpoint"
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
                      grouping = {
                        dimension = "BackendSettingsPool"
                        sort      = 2
                        top       = 10
                      }
                      metrics = [{
                        aggregationType = 4
                        metricVisualization = {
                          displayName = "Unhealthy Host Count"
                        }
                        name      = "UnhealthyHostCount"
                        namespace = "microsoft.network/applicationgateways"
                        resourceMetadata = {
                          id = azurerm_application_gateway.ingress.id
                        }
                      }]
                      title     = "Avg Unhealthy Host Count by Endpoint"
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
              y       = 8
            }
          },
          "6" = { // Log Analytics Failed Requests
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
                      azurerm_log_analytics_workspace.ingress.id
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
                  value      = "AzureDiagnostics | where ResourceType == \"APPLICATIONGATEWAYS\" and OperationName == \"ApplicationGatewayAccess\" and httpStatus_d > 399 | project timeStamp_t, clientIP_s, listenerName_s, httpMethod_s, requestUri_s, httpStatus_d | project-rename Time=timeStamp_t, ClientIP=clientIP_s, Listener=listenerName_s, Method=httpMethod_s, Path=requestUri_s, HttpStatus=httpStatus_d | sort by Time | take 100"
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
                  value      = "Analytics"
                },
                {
                  isOptional = true
                  name       = "PartSubTitle"
                  value      = azurerm_application_gateway.ingress.name
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
                  PartTitle = "Failed Requests"
                }
              }
              type = "Extension/Microsoft_OperationsManagementSuite_Workspace/PartType/LogsDashboardPart"
            }
            position = {
              colSpan = 12
              rowSpan = 8
              x       = 0
              y       = 12
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
