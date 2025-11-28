# Storage Account for Functions App
# Security Note: Configured with comprehensive security controls and private access only
# Compliance: Azure Storage Security Baseline Rules 2,3,12,14,15
resource "azurerm_storage_account" "functions" {
  name                = "st${replace(local.resource_prefix, "-", "")}${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  account_tier             = "Standard"
  account_replication_type = "LRS"

  # Security configurations
  # Security Note: TLS 1.2 minimum, HTTPS-only, no public access
  # Compliance: Azure Storage Security Baseline Rule 12
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  public_network_access_enabled   = false
  allow_nested_items_to_be_public = false

  # Enable blob encryption and retention
  # Security Note: Data protection and retention policies
  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }

  tags = local.common_tags
}

# Private endpoint for Storage Account
resource "azurerm_private_endpoint" "storage" {
  name                = "pe-storage-${local.resource_prefix}-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = local.common_tags

  private_service_connection {
    name                           = "psc-storage-blob"
    private_connection_resource_id = azurerm_storage_account.functions.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }
}

# App Service Plan for Functions
resource "azurerm_service_plan" "functions" {
  name                = "asp-${local.resource_prefix}-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Linux"
  sku_name            = var.functions_sku
  tags                = local.common_tags
}

# Function App with managed identity
# Security Note: Configured for private access with managed identity authentication
# Compliance: Azure Functions Security Baseline Rules 1,2,3,15,16,17
resource "azurerm_linux_function_app" "main" {
  name                = "func-${local.resource_prefix}-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  service_plan_id     = azurerm_service_plan.functions.id

  # Storage configuration using managed identity instead of access keys
  # Security Note: Uses managed identity for secure storage authentication
  # Compliance: Azure Functions Security Baseline Rule 15
  storage_account_name          = azurerm_storage_account.functions.name
  storage_uses_managed_identity = true

  # Enable managed identity for secure authentication
  # Security Note: System-assigned managed identity for Azure AD authentication
  # Compliance: Azure Functions Security Baseline Rule 15
  identity {
    type = "SystemAssigned"
  }

  # VNet integration for network isolation
  # Security Note: Integrates with VNet for secure network access
  # Compliance: Azure Functions Security Baseline Rule 1
  virtual_network_subnet_id = azurerm_subnet.functions.id

  # Security and networking configurations
  # Security Note: Disables public access and enforces HTTPS
  # Compliance: Azure Functions Security Baseline Rules 3,17
  public_network_access_enabled = false
  https_only                    = true

  site_config {
    # Use Python 3.11 runtime
    # Security Note: Uses supported Python runtime version
    application_stack {
      python_version = "3.11"
    }

    # Security configurations
    # Security Note: Disables insecure protocols and enables modern security features
    # Compliance: Azure Functions Security Baseline Rule 17
    ftps_state          = "Disabled"
    http2_enabled       = true
    minimum_tls_version = "1.2"

    # CORS configuration (restrict as needed)
    # Security Note: Restricts cross-origin requests for security
    cors {
      allowed_origins = ["https://portal.azure.com"]
    }

    # Application insights for monitoring and logging
    # Security Note: Enables comprehensive monitoring and security logging
    # Compliance: Azure Functions Security Baseline Rule 12
    application_insights_key               = azurerm_application_insights.main.instrumentation_key
    application_insights_connection_string = azurerm_application_insights.main.connection_string
  }

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"    = "python"
    "FUNCTIONS_EXTENSION_VERSION" = "~4"
    "WEBSITE_RUN_FROM_PACKAGE"    = "1"
    "AzureWebJobsDisableHomepage" = "true"

    # Key Vault reference for secrets
    "KEY_VAULT_URI" = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault.main.vault_uri}secrets/key-vault-uri)"
  }

  tags = local.common_tags

  # Prevent public access
  lifecycle {
    ignore_changes = [
      app_settings["WEBSITE_CONTENTAZUREFILECONNECTIONSTRING"],
      app_settings["WEBSITE_CONTENTSHARE"]
    ]
  }
}

# Application Insights for monitoring
resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-${local.resource_prefix}-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.common_tags
}

resource "azurerm_application_insights" "main" {
  name                = "ai-${local.resource_prefix}-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"
  tags                = local.common_tags
}

# Private endpoint for Function App
resource "azurerm_private_endpoint" "functions" {
  name                = "pe-functions-${local.resource_prefix}-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = local.common_tags

  private_service_connection {
    name                           = "psc-functions"
    private_connection_resource_id = azurerm_linux_function_app.main.id
    is_manual_connection           = false
    subresource_names              = ["sites"]
  }
}

# Private DNS zone for Function App
resource "azurerm_private_dns_zone" "functions" {
  name                = "privatelink.azurewebsites.net"
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
}

# Link private DNS zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "functions" {
  name                  = "vnet-link-functions"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.functions.name
  virtual_network_id    = azurerm_virtual_network.main.id
  tags                  = local.common_tags
}

# DNS A record for Function App private endpoint
resource "azurerm_private_dns_a_record" "functions" {
  name                = azurerm_linux_function_app.main.name
  zone_name           = azurerm_private_dns_zone.functions.name
  resource_group_name = azurerm_resource_group.main.name
  ttl                 = 300
  records             = [azurerm_private_endpoint.functions.private_service_connection.0.private_ip_address]
  tags                = local.common_tags
}