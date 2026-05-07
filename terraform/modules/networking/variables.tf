variable "name" {
  description = "Name for the virtual network."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group to deploy networking resources into."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "address_space" {
  description = "Address space for the virtual network."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "aks_node_subnet_cidr" {
  description = "CIDR block for the AKS node subnet."
  type        = string
  default     = "10.0.1.0/24"
}

variable "aks_pod_subnet_cidr" {
  description = "CIDR block for the AKS pod subnet (used with Azure CNI Overlay)."
  type        = string
  default     = "10.0.2.0/24"
}

variable "tags" {
  description = "Tags to apply."
  type        = map(string)
  default     = {}
}
