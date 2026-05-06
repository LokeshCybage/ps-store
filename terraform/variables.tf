variable "project_name" {
  description = "Project name used for naming/tagging."
  type        = string
  default     = "ps-store"
}

variable "environment" {
  description = "Deployment environment (e.g., dev, prod)."
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region (e.g., eastus, westeurope)."
  type        = string
}

variable "name_prefix" {
  description = "Prefix used in resource naming (should be short, lowercase preferred)."
  type        = string
  default     = "ps"
}

variable "tags" {
  description = "Extra tags to apply to all resources."
  type        = map(string)
  default     = {}
}

variable "vnet_address_space" {
  description = "Address space for the AKS virtual network."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "aks_node_subnet_cidr" {
  description = "CIDR for AKS node subnet."
  type        = string
  default     = "10.0.1.0/24"
}

variable "aks_pod_subnet_cidr" {
  description = "CIDR for AKS pod subnet (used with Azure CNI Overlay mode)."
  type        = string
  default     = "10.0.2.0/24"
}

variable "acr_sku" {
  description = "ACR SKU (Basic/Standard/Premium)."
  type        = string
  default     = "Standard"
}

variable "aks_kubernetes_version" {
  description = "AKS Kubernetes version (optional). Leave null to use platform default."
  type        = string
  default     = null
}

variable "aks_system_node_vm_size" {
  description = "VM size for the system node pool."
  type        = string
  default     = "Standard_D2s_v3"
}

variable "aks_system_node_count" {
  description = "Initial node count for the system node pool."
  type        = number
  default     = 2
}

variable "enable_log_analytics" {
  description = "Whether to create and attach a Log Analytics workspace for AKS monitoring."
  type        = bool
  default     = true
}

