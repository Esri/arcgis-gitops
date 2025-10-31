# Copyright 2025 Esri
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

# Deployment dashboard
resource "azurerm_portal_dashboard" "deployment" {
  name                = "${var.site_id}-${var.deployment_id}"
  resource_group_name = azurerm_resource_group.deployment_rg.name
  location            = azurerm_resource_group.deployment_rg.location
  dashboard_properties = jsonencode({
    lenses = {
      "0" = {
        order = 0
        parts = {
          "0" = { // Available Memory Bytes
            metadata = {
              inputs = [{
                isOptional = true
                name       = "options"
                value = {
                  chart = {
                    metrics = [{
                      aggregationType = 4
                      metricVisualization = {
                        displayName = "Available Memory Bytes"
                      }
                      name      = "Available Memory Bytes"
                      namespace = "microsoft.compute/virtualmachines"
                      resourceMetadata = {
                        id = azurerm_windows_virtual_machine.vms[0].id
                      }
                    }]
                    timespan = {
                      grain = 1
                      relative = {
                        duration = 86400000
                      }
                      showUTCTime = false
                    }
                    title     = "Avg Available Memory Bytes"
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
                        aggregationType = 4
                        metricVisualization = {
                          displayName = "Available Memory Bytes"
                        }
                        name      = "Available Memory Bytes"
                        namespace = "microsoft.compute/virtualmachines"
                        resourceMetadata = {
                          region = azurerm_resource_group.deployment_rg.location
                          resourceType = "microsoft.compute/virtualmachines"
                          subscription = {
                            subscriptionId = data.azurerm_client_config.current.subscription_id
                          }
                        }
                      }]
                      title     = "Avg Available Memory Bytes"
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
                            key = "Microsoft.ResourceId"
                            operator = 0
                            values = azurerm_windows_virtual_machine.vms.*.id
                          }
                        ]
                      }
                      grouping = {
                        dimension = "Microsoft.ResourceId"
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
          "1" = { // CPU Percentage
            metadata = {
              inputs = [{
                isOptional = true
                name       = "options"
                value = {
                  chart = {
                    metrics = [{
                      aggregationType = 4
                      metricVisualization = {
                        displayName = "Percentage CPU"
                      }
                      name      = "Percentage CPU"
                      namespace = "microsoft.compute/virtualmachines"
                      resourceMetadata = {
                        id = azurerm_windows_virtual_machine.vms[0].id
                      }
                    }]
                    timespan = {
                      grain = 1
                      relative = {
                        duration = 86400000
                      }
                      showUTCTime = false
                    }
                    title     = "Avg Percentage CPU"
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
                        aggregationType = 4
                        metricVisualization = {
                          displayName = "Percentage CPU"
                        }
                        name      = "Percentage CPU"
                        namespace = "microsoft.compute/virtualmachines"
                        resourceMetadata = {
                          region = azurerm_resource_group.deployment_rg.location
                          resourceType = "microsoft.compute/virtualmachines"
                          subscription = {
                            subscriptionId = data.azurerm_client_config.current.subscription_id
                          }
                        }
                      }]
                      title     = "Avg Percentage CPU"
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
                            key = "Microsoft.ResourceId"
                            operator = 0
                            values = azurerm_windows_virtual_machine.vms.*.id
                          }
                        ]
                      }
                      grouping = {
                        dimension = "Microsoft.ResourceId"
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
          "2" = { // OS Disk Read Bytes/sec
            metadata = {
              inputs = [{
                isOptional = true
                name       = "options"
                value = {
                  chart = {
                    metrics = [{
                      aggregationType = 4
                      metricVisualization = {
                        displayName = "OS Disk Read Bytes/sec"
                      }
                      name      = "OS Disk Read Bytes/sec"
                      namespace = "microsoft.compute/virtualmachines"
                      resourceMetadata = {
                        id = azurerm_windows_virtual_machine.vms[0].id
                      }
                    }]
                    timespan = {
                      grain = 1
                      relative = {
                        duration = 86400000
                      }
                      showUTCTime = false
                    }
                    title     = "Avg OS Disk Read Bytes/sec"
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
                        aggregationType = 4
                        metricVisualization = {
                          displayName = "OS Disk Read Bytes/sec"
                        }
                        name      = "OS Disk Read Bytes/sec"
                        namespace = "microsoft.compute/virtualmachines"
                        resourceMetadata = {
                          region = azurerm_resource_group.deployment_rg.location
                          resourceType = "microsoft.compute/virtualmachines"
                          subscription = {
                            subscriptionId = data.azurerm_client_config.current.subscription_id
                          }
                        }
                      }]
                      title     = "Avg OS Disk Read Bytes/sec"
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
                            key = "Microsoft.ResourceId"
                            operator = 0
                            values = azurerm_windows_virtual_machine.vms.*.id
                          }
                        ]
                      }
                      grouping = {
                        dimension = "Microsoft.ResourceId"
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
          "3" = { // OS Disk Write Bytes/sec
            metadata = {
              inputs = [{
                isOptional = true
                name       = "options"
                value = {
                  chart = {
                    metrics = [{
                      aggregationType = 4
                      metricVisualization = {
                        displayName = "OS Disk Write Bytes/sec"
                      }
                      name      = "OS Disk Write Bytes/sec"
                      namespace = "microsoft.compute/virtualmachines"
                      resourceMetadata = {
                        id = azurerm_windows_virtual_machine.vms[0].id
                      }
                    }]
                    timespan = {
                      grain = 1
                      relative = {
                        duration = 86400000
                      }
                      showUTCTime = false
                    }
                    title     = "Avg OS Disk Write Bytes/sec"
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
                        aggregationType = 4
                        metricVisualization = {
                          displayName = "OS Disk Write Bytes/sec"
                        }
                        name      = "OS Disk Write Bytes/sec"
                        namespace = "microsoft.compute/virtualmachines"
                        resourceMetadata = {
                          region = azurerm_resource_group.deployment_rg.location
                          resourceType = "microsoft.compute/virtualmachines"
                          subscription = {
                            subscriptionId = data.azurerm_client_config.current.subscription_id
                          }
                        }
                      }]
                      title     = "Avg OS Disk Write Bytes/sec"
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
                            key = "Microsoft.ResourceId"
                            operator = 0
                            values = azurerm_windows_virtual_machine.vms.*.id
                          }
                        ]
                      }
                      grouping = {
                        dimension = "Microsoft.ResourceId"
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
        }
      }
    }
  })

  tags = {
    ArcGISSiteId       = var.site_id
    ArcGISDeploymentId = var.deployment_id
  }
}
