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

# Bastion subnet

resource "azurerm_subnet" "bastion_subnet" {
  name                            = "AzureBastionSubnet"
  resource_group_name             = azurerm_resource_group.site_rg.name
  virtual_network_name            = azurerm_virtual_network.site_vnet.name
  default_outbound_access_enabled = false
  address_prefixes = [
    var.bastion_subnet_cidr_block
  ]
}

# Bastion NSG

resource "azurerm_network_security_group" "bastion_nsg" {
  name                = "${var.site_id}-bastion"
  location            = azurerm_resource_group.site_rg.location
  resource_group_name = azurerm_resource_group.site_rg.name
}

# Ingress Traffic from public internet: The Azure Bastion will create a public IP
# that needs port 443 enabled on the public IP for ingress traffic. 
# Port 3389/22 are NOT required to be opened on the AzureBastionSubnet. 
resource "azurerm_network_security_rule" "allow_https_inbound" {
  network_security_group_name = azurerm_network_security_group.bastion_nsg.name
  resource_group_name         = azurerm_resource_group.site_rg.name
  name                        = "AllowHTTPSInBound"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefixes     = var.bastion_source_cidr_blocks
  destination_address_prefix  = "*"
}

# Ingress Traffic from Azure Bastion control plane: For control plane connectivity,
# enable port 443 inbound from GatewayManager service tag. 
# This enables the control plane, that is, Gateway Manager to be able to talk to Azure Bastion.
resource "azurerm_network_security_rule" "allow_gateway_manager_inbound" {
  network_security_group_name = azurerm_network_security_group.bastion_nsg.name
  resource_group_name         = azurerm_resource_group.site_rg.name
  name                        = "AllowGatewayManagerInBound"
  priority                    = 121
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "GatewayManager"
  destination_address_prefix  = "*"
}

# Ingress Traffic from Azure Load Balancer: For health probes, enable port 443 inbound
# from the AzureLoadBalancer service tag. 
# This enables Azure Load Balancer to detect connectivity.
resource "azurerm_network_security_rule" "allow_azure_load_balancer_inbound" {
  network_security_group_name = azurerm_network_security_group.bastion_nsg.name
  resource_group_name         = azurerm_resource_group.site_rg.name
  name                        = "AllowAzureLoadBalancerInBound"
  priority                    = 122
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "*"
}

# Ingress Traffic from Azure Bastion data plane: For data plane communication 
# between the underlying components of Azure Bastion, enable ports 8080, 5701 inbound
# from the VirtualNetwork service tag to the VirtualNetwork service tag. 
# This enables the components of Azure Bastion to talk to each other.
resource "azurerm_network_security_rule" "allow_bastion_host_communication_inbound" {
  network_security_group_name = azurerm_network_security_group.bastion_nsg.name
  resource_group_name         = azurerm_resource_group.site_rg.name
  name                        = "AllowBastionHostCommunication"
  priority                    = 123
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["5701", "8080"]
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
}

# Egress Traffic to target VMs: Azure Bastion will reach the target VMs over private IP. 
# The NSGs need to allow egress traffic to other target VM subnets for port 3389 and 22.
# If you're utilizing the custom port functionality within the Standard SKU, 
# ensure that NSGs allow outbound traffic to the service tag VirtualNetwork as the destination.
resource "azurerm_network_security_rule" "allow_ssh_rdp_outbound" {
  network_security_group_name = azurerm_network_security_group.bastion_nsg.name
  resource_group_name         = azurerm_resource_group.site_rg.name
  name                        = "AllowSSHRDPOutBound"
  priority                    = 101
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["22", "3389"]
  source_address_prefix       = "*"
  destination_address_prefix  = "VirtualNetwork"
}

# Egress Traffic to other public endpoints in Azure: Azure Bastion needs to be
# able to connect to various public endpoints within Azure 
# (for example, for storing diagnostics logs and metering logs). 
# For this reason, Azure Bastion needs outbound to 443 to AzureCloud service tag.
resource "azurerm_network_security_rule" "allow_azure_cloud_outbound" {
  network_security_group_name = azurerm_network_security_group.bastion_nsg.name
  resource_group_name         = azurerm_resource_group.site_rg.name
  name                        = "AllowAzureCloudOutBound"
  priority                    = 102
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["443"]
  source_address_prefix       = "*"
  destination_address_prefix  = "AzureCloud"
}

# Egress Traffic to Azure Bastion data plane: For data plane communication 
# between the underlying components of Azure Bastion, enable ports 8080, 5701 outbound
# from the VirtualNetwork service tag to the VirtualNetwork service tag. 
# This enables the components of Azure Bastion to talk to each other.
resource "azurerm_network_security_rule" "allow_bastion_communications_outbound" {
  network_security_group_name = azurerm_network_security_group.bastion_nsg.name
  resource_group_name         = azurerm_resource_group.site_rg.name
  name                        = "AllowBastionCommunication"
  priority                    = 103
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_ranges     = ["5701", "8080"]
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
}

# Egress Traffic to Internet: Azure Bastion needs to be able to communicate with 
# the Internet for session, Bastion Shareable Link, and certificate validation.
# For this reason, we recommend enabling port 80 outbound to the Internet.
resource "azurerm_network_security_rule" "allow_http_outbound" {
  network_security_group_name = azurerm_network_security_group.bastion_nsg.name
  resource_group_name         = azurerm_resource_group.site_rg.name
  name                        = "AllowHTTPOutBound"
  priority                    = 104
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_ranges     = ["80"]
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
}

resource "azurerm_subnet_network_security_group_association" "bastion_subnet" {
  subnet_id                 = azurerm_subnet.bastion_subnet.id
  network_security_group_id = azurerm_network_security_group.bastion_nsg.id
  # Ensure that the NSG rules are created before the NSG association is created
  depends_on = [
    azurerm_network_security_rule.allow_https_inbound,
    azurerm_network_security_rule.allow_gateway_manager_inbound,
    azurerm_network_security_rule.allow_azure_load_balancer_inbound,
    azurerm_network_security_rule.allow_bastion_host_communication_inbound,
    azurerm_network_security_rule.allow_ssh_rdp_outbound,
    azurerm_network_security_rule.allow_azure_cloud_outbound,
    azurerm_network_security_rule.allow_bastion_communications_outbound,
    azurerm_network_security_rule.allow_http_outbound
  ]
}

resource "azurerm_public_ip" "bastion" {
  name                = "${var.site_id}-bastion"
  location            = azurerm_resource_group.site_rg.location
  resource_group_name = azurerm_resource_group.site_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "bastion" {
  count               = var.bastion_enabled ? 1 : 0
  name                = "${var.site_id}-bastion"
  location            = azurerm_resource_group.site_rg.location
  resource_group_name = azurerm_resource_group.site_rg.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion_subnet.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }

  depends_on = [
    azurerm_subnet_network_security_group_association.bastion_subnet,
    azurerm_network_security_rule.allow_azure_cloud_outbound,
    azurerm_network_security_rule.allow_bastion_communications_outbound,
    azurerm_network_security_rule.allow_http_outbound,
    azurerm_network_security_rule.allow_ssh_rdp_outbound,
    azurerm_network_security_rule.allow_https_inbound,
    azurerm_network_security_rule.allow_gateway_manager_inbound,
    azurerm_network_security_rule.allow_azure_load_balancer_inbound,
    azurerm_network_security_rule.allow_bastion_host_communication_inbound
  ]
}
