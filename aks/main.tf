terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

resource "azurerm_resource_group" "aks" {
  name     = "terraform-rg-aks"
  location = var.location
}

resource "azurerm_kubernetes_cluster" "main" {
  name                = "terraform-aks-cluster"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  dns_prefix          = "terraform-aks"
  #make sure to lockdown the version of kubernetes to avoid unexpected changes
  kubernetes_version  = data.azurerm_kubernetes_service_versions.current.default_version
  oidc_issuer_enabled = true

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = var.size
    upgrade_settings {
      max_surge                     = "10%"
      drain_timeout_in_minutes      = 0
      node_soak_duration_in_minutes = 0
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin      = "azure"
    network_policy      = "cilium"
    network_data_plane  = "cilium"
    network_plugin_mode = "overlay"
  }

  key_vault_secrets_provider {
    secret_rotation_enabled = false
  }
}

# DB

resource "azurerm_postgresql_flexible_server" "n8n_db" {

  name                = "psql-n8n-aks"
  resource_group_name = azurerm_resource_group.aks.name
  location            = azurerm_resource_group.aks.location
  # zone                = "2"

  administrator_login    = var.postgres_admin_username
  administrator_password = var.postgres_admin_password

  sku_name   = "B_Standard_B1ms"
  storage_mb = 32768
  version    = "16"

  backup_retention_days = 7

  # Allow Azure services access (needed for AKS)
  public_network_access_enabled = true

  lifecycle {
    # Protect the database from accidental destruction by Terraform.
    prevent_destroy = true

    # Azure assigns the zone when one isn't specified. Ignore that computed value
    # so Terraform doesn't try to unset or reconcile it on later applies.
    ignore_changes = [
      zone
    ]
  }
}

resource "azurerm_postgresql_flexible_server_database" "n8n" {
  name      = "n8n"
  server_id = azurerm_postgresql_flexible_server.n8n_db.id
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_postgresql_flexible_server.n8n_db.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# Key Vault
resource "azurerm_key_vault" "aks_key_vault" {
  name                = "kv-n8n-aks"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  # Make it easy to destroy and recreate
  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  # Allow Terraform to manage secrets
  rbac_authorization_enabled = true
  depends_on                 = [azurerm_kubernetes_cluster.main]
}

# Give yourself permission to manage secrets
resource "azurerm_role_assignment" "kv_admin" {
  scope                = azurerm_key_vault.aks_key_vault.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "aks_keyvault_secrets_provider" {
  # Allow the AKS Key Vault CSI provider identity to read secrets
  # from this vault when requested by Kubernetes workloads.
  scope                = azurerm_key_vault.aks_key_vault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_kubernetes_cluster.main.key_vault_secrets_provider[0].secret_identity[0].object_id
}

# Create the secrets
resource "azurerm_key_vault_secret" "db_host" {
  name         = "db-host"
  value        = azurerm_postgresql_flexible_server.n8n_db.fqdn
  key_vault_id = azurerm_key_vault.aks_key_vault.id

  depends_on = [azurerm_role_assignment.kv_admin]
}

resource "azurerm_key_vault_secret" "db_name" {
  name         = "db-name"
  value        = azurerm_postgresql_flexible_server_database.n8n.name
  key_vault_id = azurerm_key_vault.aks_key_vault.id

  depends_on = [azurerm_role_assignment.kv_admin]
}

resource "azurerm_key_vault_secret" "db_user" {
  name         = "db-user"
  value        = azurerm_postgresql_flexible_server.n8n_db.administrator_login
  key_vault_id = azurerm_key_vault.aks_key_vault.id

  depends_on = [azurerm_role_assignment.kv_admin]
}

resource "azurerm_key_vault_secret" "db_password" {
  name         = "db-password"
  value        = var.postgres_admin_password
  key_vault_id = azurerm_key_vault.aks_key_vault.id

  depends_on = [azurerm_role_assignment.kv_admin]
}

resource "azurerm_key_vault_secret" "n8n_encryption_key" {
  name         = "n8n-encryption-key"
  value        = var.n8n_encryption_key
  key_vault_id = azurerm_key_vault.aks_key_vault.id
  # Keep the encryption key stable across redeployments.
  # Changing it would prevent n8n from decrypting credentials encrypted with the previous key.
  depends_on = [azurerm_role_assignment.kv_admin]
}
