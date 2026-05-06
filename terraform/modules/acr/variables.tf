variable "name" {
  description = "ACR name (5-50 alphanumeric lowercase characters)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{5,50}$", var.name))
    error_message = "ACR name must be 5-50 lowercase alphanumeric characters."
  }
}

variable "resource_group_name" {
  description = "Resource group to deploy the ACR into."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "sku" {
  description = "ACR SKU (Basic/Standard/Premium)."
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.sku)
    error_message = "ACR SKU must be Basic, Standard, or Premium."
  }
}

variable "georeplications" {
  description = "List of locations to geo-replicate the ACR to (Premium SKU only)."
  type = list(object({
    location                = string
    zone_redundancy_enabled = bool
  }))
  default = []
}

variable "tags" {
  description = "Tags to apply."
  type        = map(string)
  default     = {}
}
