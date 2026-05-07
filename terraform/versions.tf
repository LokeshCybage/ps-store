terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  # Configure remote state (recommended).
  # Provide backend config via:
  # - `terraform init -backend-config=...`
  # - or a `backend.hcl` file (not committed).
  backend "azurerm" {}
}

provider "azurerm" {
  features {
    # AKS + OMS can leave ContainerInsights solutions in the RG; allow RG delete to
    # cascade via the Azure API so destroy does not block on nested ARM resources.
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  # azurerm v4 requires an explicit subscription_id; supplied via ARM_SUBSCRIPTION_ID
  # environment variable so this file stays free of subscription-specific values.
}

