variable "scope_resource_id" {
  description = "Resource ID to scope the AcrPull role assignment to (the ACR resource ID)."
  type        = string
}

variable "kubelet_principal_id" {
  description = "Object ID of the AKS kubelet managed identity."
  type        = string
}

variable "tags" {
  description = "Tags (not applied to role assignments, but kept for consistency and future resources)."
  type        = map(string)
  default     = {}
}
