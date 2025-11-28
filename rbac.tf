# Role assignment for APIM to access Key Vault secrets
resource "azurerm_role_assignment" "apim_keyvault_reader" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_api_management.main.identity[0].principal_id
}

# Role assignment for Functions to access Key Vault secrets
resource "azurerm_role_assignment" "functions_keyvault_reader" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_function_app.main.identity[0].principal_id
}

# Role assignment for Functions to access Storage Account
resource "azurerm_role_assignment" "functions_storage_contributor" {
  scope                = azurerm_storage_account.functions.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_function_app.main.identity[0].principal_id
}