
output "db_host" {
  value = azurerm_postgresql_flexible_server.n8n_db.fqdn
}

output "db_name" {
  value = azurerm_postgresql_flexible_server_database.n8n.name
}

output "db_user" {
  value = azurerm_postgresql_flexible_server.n8n_db.administrator_login
}

output "key_vault_name" {
  value = azurerm_key_vault.aks_key_vault.name
}

output "key_vault_uri" {
  value = azurerm_key_vault.aks_key_vault.vault_uri
}

output "aks_keyvault_secrets_provider_client_id" {
  value       = azurerm_kubernetes_cluster.main.key_vault_secrets_provider[0].secret_identity[0].client_id
  description = "AKS Key Vault Secrets Provider Client ID (userAssignedIdentityID) for use in SecretProviderClass"
}
