locals {
  base_name = "${var.name_prefix}-${var.project_name}-${var.environment}"

  # ACR name rules: 5-50 alphanumeric, lowercase.
  acr_name = substr(
    lower(replace("${var.name_prefix}${var.project_name}${var.environment}", "/[^0-9a-z]/", "")),
    0,
    50
  )

  default_tags = merge(
    {
      project     = var.project_name
      environment = var.environment
      managed_by  = "terraform"
    },
    var.tags
  )
}

module "resource_group" {
  source   = "./modules/resource-group"
  name     = "${local.base_name}-rg"
  location = var.location
  tags     = local.default_tags
}

module "networking" {
  source              = "./modules/networking"
  name                = "${local.base_name}-vnet"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location

  address_space        = var.vnet_address_space
  aks_node_subnet_cidr = var.aks_node_subnet_cidr
  aks_pod_subnet_cidr  = var.aks_pod_subnet_cidr
  tags                 = local.default_tags
}

module "acr" {
  source              = "./modules/acr"
  name                = local.acr_name
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  sku                 = var.acr_sku
  tags                = local.default_tags
}

module "aks" {
  source              = "./modules/aks"
  name                = "${local.base_name}-aks"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location

  kubernetes_version   = var.aks_kubernetes_version
  subnet_id            = module.networking.aks_node_subnet_id
  pod_subnet_id        = module.networking.aks_pod_subnet_id
  system_node_vm_size  = var.aks_system_node_vm_size
  system_node_count    = var.aks_system_node_count
  enable_log_analytics = var.enable_log_analytics

  tags = local.default_tags
}

module "iam" {
  source = "./modules/iam"

  scope_resource_id    = module.acr.id
  kubelet_principal_id = module.aks.kubelet_identity_object_id
  tags                 = local.default_tags
}

