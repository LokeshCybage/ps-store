resource "azurerm_virtual_network" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = var.address_space
  tags                = var.tags
}

resource "azurerm_subnet" "aks_nodes" {
  name                 = "aks-nodes"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.aks_node_subnet_cidr]
}

resource "azurerm_subnet" "aks_pods" {
  name                 = "aks-pods"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.aks_pod_subnet_cidr]

  # Required delegation for Azure CNI Overlay (pod subnet).
  delegation {
    name = "aks-delegation"
    service_delegation {
      name    = "Microsoft.ContainerService/managedClusters"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_network_security_group" "aks_nodes" {
  name                = "${var.name}-aks-nodes-nsg"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_subnet_network_security_group_association" "aks_nodes" {
  subnet_id                 = azurerm_subnet.aks_nodes.id
  network_security_group_id = azurerm_network_security_group.aks_nodes.id
}

# Allow inbound HTTP/HTTPS to ingress controller LoadBalancer-backed pods.
# Source = Internet so the cluster can serve public traffic via the AKS LB.
resource "azurerm_network_security_rule" "allow_http" {
  name                        = "AllowHTTPInbound"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.aks_nodes.name
  priority                    = 1000
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_address_prefix       = "Internet"
  source_port_range           = "*"
  destination_address_prefix  = "*"
  destination_port_range      = "80"
}

resource "azurerm_network_security_rule" "allow_https" {
  name                        = "AllowHTTPSInbound"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.aks_nodes.name
  priority                    = 1010
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_address_prefix       = "Internet"
  source_port_range           = "*"
  destination_address_prefix  = "*"
  destination_port_range      = "443"
}
