data "azurerm_kubernetes_service_versions" "current" {
  # used to get the current Kubernetes version available in the specified location.
  location = var.location
}

data "azurerm_client_config" "current" {
  # used to access the configuration of the AzureRM provider.
}