output "resource_group_name" {
  value       = module.resource_group.name
  description = "Resource group containing the AKS/ACR resources."
}

output "location" {
  value       = module.resource_group.location
  description = "Azure region used for the deployment."
}

output "acr_id" {
  value       = module.acr.id
  description = "ACR resource ID."
}

output "acr_login_server" {
  value       = module.acr.login_server
  description = "ACR login server (e.g., <name>.azurecr.io)."
}

output "aks_name" {
  value       = module.aks.name
  description = "AKS cluster name."
}

output "aks_kubelet_identity_object_id" {
  value       = module.aks.kubelet_identity_object_id
  description = "Object ID for the AKS kubelet identity (used for AcrPull role assignment)."
}

output "aks_kube_config" {
  value       = module.aks.kube_config
  description = "Kubeconfig for the AKS cluster."
  sensitive   = true
}

