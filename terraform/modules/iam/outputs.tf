output "acr_pull_role_assignment_id" {
  value       = azurerm_role_assignment.aks_acr_pull.id
  description = "Resource ID of the AcrPull role assignment."
}
