# Grant AKS kubelet identity the AcrPull role on ACR.
# This allows node pools to pull container images without admin credentials.
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = var.scope_resource_id
  role_definition_name = "AcrPull"
  principal_id         = var.kubelet_principal_id

  # Skip the AAD check: the principal is a managed identity, not an AAD user.
  skip_service_principal_aad_check = true
}
