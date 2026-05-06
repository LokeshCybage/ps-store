variable "name" {
  description = "AKS cluster name."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group to deploy the AKS cluster into."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version. Set to null to use the platform default."
  type        = string
  default     = null
}

variable "subnet_id" {
  description = "Subnet ID for AKS node VMs."
  type        = string
}

variable "pod_subnet_id" {
  description = "Subnet ID for AKS pods (Azure CNI Overlay)."
  type        = string
}

variable "system_node_vm_size" {
  description = "VM size for the system node pool."
  type        = string
  default     = "Standard_D2s_v3"
}

variable "system_node_count" {
  description = "Initial node count for the system node pool."
  type        = number
  default     = 2
}

variable "system_node_min_count" {
  description = "Minimum node count (autoscaler)."
  type        = number
  default     = 1
}

variable "system_node_max_count" {
  description = "Maximum node count (autoscaler)."
  type        = number
  default     = 5
}

variable "os_disk_size_gb" {
  description = "OS disk size in GB for node pool VMs."
  type        = number
  default     = 128
}

variable "enable_log_analytics" {
  description = "Create a Log Analytics workspace and attach it to the AKS OMS agent."
  type        = bool
  default     = true
}

variable "log_analytics_sku" {
  description = "Log Analytics workspace SKU."
  type        = string
  default     = "PerGB2018"
}

variable "log_analytics_retention_days" {
  description = "Log Analytics workspace retention in days."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags to apply."
  type        = map(string)
  default     = {}
}
