resource "azurerm_log_analytics_workspace" "this" {
  count = var.enable_log_analytics ? 1 : 0

  name                = "${var.name}-law"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.log_analytics_sku
  retention_in_days   = var.log_analytics_retention_days
  tags                = var.tags
}

resource "azurerm_kubernetes_cluster" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  kubernetes_version  = var.kubernetes_version

  # DNS prefix is derived from the cluster name, keeping it deterministic.
  dns_prefix = var.name

  # Use system-assigned managed identity; the kubelet identity is auto-created.
  identity {
    type = "SystemAssigned"
  }

  default_node_pool {
    name                         = "system"
    vm_size                      = var.system_node_vm_size
    node_count                   = var.system_node_count
    min_count                    = var.system_node_min_count
    max_count                    = var.system_node_max_count
    auto_scaling_enabled         = true
    os_disk_size_gb              = var.os_disk_size_gb
    vnet_subnet_id               = var.subnet_id
    only_critical_addons_enabled = false

    upgrade_settings {
      max_surge = "10%"
    }
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    load_balancer_sku   = "standard"
    # Service / cluster-internal CIDRs MUST NOT overlap the VNet (10.0.0.0/16).
    service_cidr   = "10.100.0.0/16"
    dns_service_ip = "10.100.0.10"
    pod_cidr       = "10.244.0.0/16"
  }

  # Enable OIDC issuer so Workload Identity federation works.
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  dynamic "oms_agent" {
    for_each = var.enable_log_analytics ? [1] : []
    content {
      log_analytics_workspace_id = azurerm_log_analytics_workspace.this[0].id
    }
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [
      # Ignore node count changes made by the autoscaler.
      default_node_pool[0].node_count,
    ]
  }
}
