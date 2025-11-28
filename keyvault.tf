# Get current client configuration
data "azurerm_client_config" "current" {}

# Key Vault for secure secrets management
# Security Note: Configured with comprehensive security controls and private access
# Compliance: Azure Key Vault Security Baseline Rules 1,8,10,13,14,17
resource "azurerm_key_vault" "main" {
  name                = "kv-${local.resource_prefix}-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"
  tags                = local.common_tags

  # Enable RBAC authorization for least privilege access
  # Security Note: Uses Azure RBAC instead of access policies for better security
  # Compliance: Azure Key Vault Security Baseline Rule 10
  enable_rbac_authorization = true

  # Network access configuration - disable public access
  # Security Note: Prevents access from public internet
  # Compliance: Azure Key Vault Security Baseline Rule 8
  public_network_access_enabled = false

  # Network access control lists
  # Security Note: Denies all access by default, allows only specific VNet subnets
  # Compliance: Azure Key Vault Security Baseline Rules 2,8
  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    virtual_network_subnet_ids = [
      azurerm_subnet.apim.id,
      azurerm_subnet.functions.id
    ]
  }

  # Security features
  # Security Note: Purge protection prevents permanent deletion of secrets
  # Set to false for development, true for production environments
  # Compliance: Azure Key Vault Security Baseline Rule 17
  # tfsec:ignore:azure-keyvault-no-purge - Intentionally disabled for dev environment
  purge_protection_enabled   = var.environment == "prod" ? true : false
  soft_delete_retention_days = var.environment == "prod" ? 90 : 7
}

# Private endpoint for Key Vault
resource "azurerm_private_endpoint" "keyvault" {
  name                = "pe-keyvault-${local.resource_prefix}-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = local.common_tags

  private_service_connection {
    name                           = "psc-keyvault"
    private_connection_resource_id = azurerm_key_vault.main.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }
}

# Private DNS zone for Key Vault
resource "azurerm_private_dns_zone" "keyvault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
}

# Link private DNS zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "keyvault" {
  name                  = "vnet-link-keyvault"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.keyvault.name
  virtual_network_id    = azurerm_virtual_network.main.id
  tags                  = local.common_tags
}

# DNS A record for Key Vault private endpoint
resource "azurerm_private_dns_a_record" "keyvault" {
  name                = azurerm_key_vault.main.name
  zone_name           = azurerm_private_dns_zone.keyvault.name
  resource_group_name = azurerm_resource_group.main.name
  ttl                 = 300
  records             = [azurerm_private_endpoint.keyvault.private_service_connection.0.private_ip_address]
  tags                = local.common_tags
}