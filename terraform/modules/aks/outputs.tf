output "id" {
  value       = azurerm_kubernetes_cluster.this.id
  description = "AKS cluster resource ID."
}

output "name" {
  value       = azurerm_kubernetes_cluster.this.name
  description = "AKS cluster name."
}

output "kube_config" {
  value       = azurerm_kubernetes_cluster.this.kube_config_raw
  description = "Raw kubeconfig for the AKS cluster."
  sensitive   = true
}

output "host" {
  value       = azurerm_kubernetes_cluster.this.kube_config[0].host
  description = "Kubernetes API server host."
  sensitive   = true
}

output "kubelet_identity_object_id" {
  value       = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
  description = "Object ID of the kubelet managed identity (used for AcrPull role assignment)."
}

output "kubelet_identity_client_id" {
  value       = azurerm_kubernetes_cluster.this.kubelet_identity[0].client_id
  description = "Client ID of the kubelet managed identity."
}

output "oidc_issuer_url" {
  value       = azurerm_kubernetes_cluster.this.oidc_issuer_url
  description = "OIDC issuer URL for Workload Identity federation."
}

output "log_analytics_workspace_id" {
  value       = var.enable_log_analytics ? azurerm_log_analytics_workspace.this[0].id : null
  description = "Log Analytics workspace resource ID (null when disabled)."
}
