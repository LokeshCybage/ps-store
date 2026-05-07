output "vnet_id" {
  value       = azurerm_virtual_network.this.id
  description = "Virtual network resource ID."
}

output "vnet_name" {
  value       = azurerm_virtual_network.this.name
  description = "Virtual network name."
}

output "aks_node_subnet_id" {
  value       = azurerm_subnet.aks_nodes.id
  description = "Subnet ID for AKS node pool."
}

output "aks_pod_subnet_id" {
  value       = azurerm_subnet.aks_pods.id
  description = "Subnet ID for AKS pod overlay (Azure CNI Overlay)."
}

output "aks_nodes_nsg_id" {
  value       = azurerm_network_security_group.aks_nodes.id
  description = "NSG ID associated with the AKS node subnet."
}
