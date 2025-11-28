# API Management
# Security Note: Configured for internal VNet mode with comprehensive security controls
# Compliance: Azure APIM Security Baseline Rules 1,2,6,9,14,15
resource "azurerm_api_management" "main" {
  name                = "apim-${local.resource_prefix}-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  publisher_name      = var.publisher_name
  publisher_email     = var.publisher_email

  sku_name = "${var.apim_sku}_${var.apim_capacity}"

  # Enable managed identity for secure authentication
  # Security Note: Uses system-assigned managed identity to avoid credential management
  identity {
    type = "SystemAssigned"
  }

  # Virtual Network configuration (Internal mode for security)
  # Security Note: Internal mode ensures APIM is not directly accessible from internet
  # Compliance: Azure APIM Security Baseline Rule 2
  virtual_network_type = "Internal"
  virtual_network_configuration {
    subnet_id = azurerm_subnet.apim.id
  }

  # Security configurations
  # Security Note: Minimum API version prevents sharing secrets with read-only users
  # Compliance: Azure APIM Security Baseline Rule 9
  min_api_version = "2019-12-01"

  # Enable request/response logging
  protocols {
    enable_http2 = true
  }

  # Security configurations for TLS and cipher management
  # Security Note: Disables weak cryptographic protocols and ciphers
  # Compliance: Azure APIM Security Baseline Rule 15 - Encrypted protocols only
  security {
    enable_backend_ssl30                                = false
    enable_backend_tls10                                = false
    enable_backend_tls11                                = false
    enable_frontend_ssl30                               = false
    enable_frontend_tls10                               = false
    enable_frontend_tls11                               = false
    tls_ecdhe_ecdsa_with_aes128_cbc_sha_ciphers_enabled = false
    tls_ecdhe_ecdsa_with_aes256_cbc_sha_ciphers_enabled = false
    tls_ecdhe_rsa_with_aes128_cbc_sha_ciphers_enabled   = false
    tls_ecdhe_rsa_with_aes256_cbc_sha_ciphers_enabled   = false
    tls_rsa_with_aes128_cbc_sha256_ciphers_enabled      = false
    tls_rsa_with_aes128_cbc_sha_ciphers_enabled         = false
    tls_rsa_with_aes256_cbc_sha256_ciphers_enabled      = false
    tls_rsa_with_aes256_cbc_sha_ciphers_enabled         = false
    triple_des_ciphers_enabled                          = false
  }

  tags = local.common_tags

  depends_on = [
    azurerm_subnet_network_security_group_association.apim
  ]
}

# Named Values (for storing configuration)
resource "azurerm_api_management_named_value" "function_key" {
  name                = "function-app-key"
  resource_group_name = azurerm_resource_group.main.name
  api_management_name = azurerm_api_management.main.name
  display_name        = "Function-App-Key"
  secret              = true
  value               = "temp-value" # This should be updated after Function App deployment
}

resource "azurerm_api_management_named_value" "function_url" {
  name                = "function-app-url"
  resource_group_name = azurerm_resource_group.main.name
  api_management_name = azurerm_api_management.main.name
  display_name        = "Function-App-URL"
  value               = "https://${azurerm_linux_function_app.main.name}.azurewebsites.net"
}

# Backend configuration for Functions
resource "azurerm_api_management_backend" "functions" {
  name                = "functions-backend"
  resource_group_name = azurerm_resource_group.main.name
  api_management_name = azurerm_api_management.main.name
  protocol            = "http"
  url                 = "https://${azurerm_linux_function_app.main.name}.azurewebsites.net"

  credentials {
    header = {
      "x-functions-key" = "{{function-app-key}}"
    }
  }

  tls {
    validate_certificate_chain = true
    validate_certificate_name  = true
  }
}

# API definition
resource "azurerm_api_management_api" "functions_api" {
  name                  = "functions-api"
  resource_group_name   = azurerm_resource_group.main.name
  api_management_name   = azurerm_api_management.main.name
  revision              = "1"
  display_name          = "Functions API"
  path                  = "api"
  protocols             = ["https"]
  service_url           = "https://${azurerm_linux_function_app.main.name}.azurewebsites.net/api"
  subscription_required = true

  subscription_key_parameter_names {
    header = "Ocp-Apim-Subscription-Key"
    query  = "subscription-key"
  }
}

# API Operations
resource "azurerm_api_management_api_operation" "get_hello" {
  operation_id        = "get-hello"
  api_name            = azurerm_api_management_api.functions_api.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name
  display_name        = "Get Hello"
  method              = "GET"
  url_template        = "/hello"

  description = "Get a hello message from the Python function"

  response {
    status_code = 200
    description = "Success"
    representation {
      content_type = "application/json"
    }
  }
}

resource "azurerm_api_management_api_operation" "post_data" {
  operation_id        = "post-data"
  api_name            = azurerm_api_management_api.functions_api.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name
  display_name        = "Post Data"
  method              = "POST"
  url_template        = "/process"

  description = "Process data with the Python function"

  request {
    description = "Data to process"
    representation {
      content_type = "application/json"
    }
  }

  response {
    status_code = 200
    description = "Success"
    representation {
      content_type = "application/json"
    }
  }
}

# API Policies for security
resource "azurerm_api_management_api_policy" "functions_api_policy" {
  api_name            = azurerm_api_management_api.functions_api.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name

  xml_content = <<XML
<policies>
  <inbound>
    <base />
    <!-- Rate limiting -->
    <rate-limit calls="100" renewal-period="60" />

    <!-- IP filtering - customize as needed -->
    <ip-filter action="allow">
      <address-range from="10.0.0.0" to="10.255.255.255" />
    </ip-filter>

    <!-- CORS -->
    <cors allow-credentials="false">
      <allowed-origins>
        <origin>*</origin>
      </allowed-origins>
      <allowed-methods>
        <method>GET</method>
        <method>POST</method>
        <method>OPTIONS</method>
      </allowed-methods>
      <allowed-headers>
        <header>*</header>
      </allowed-headers>
    </cors>

    <!-- Set backend service -->
    <set-backend-service backend-id="functions-backend" />
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
    <!-- Security headers -->
    <set-header name="X-Content-Type-Options" exists-action="override">
      <value>nosniff</value>
    </set-header>
    <set-header name="X-Frame-Options" exists-action="override">
      <value>DENY</value>
    </set-header>
    <set-header name="X-XSS-Protection" exists-action="override">
      <value>1; mode=block</value>
    </set-header>
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
XML
}

# Product for grouping APIs
resource "azurerm_api_management_product" "functions_product" {
  product_id            = "functions-product"
  api_management_name   = azurerm_api_management.main.name
  resource_group_name   = azurerm_resource_group.main.name
  display_name          = "Functions Product"
  description           = "Product for Python Functions API"
  subscription_required = true
  published             = true

  # Scoped to this product only (not all APIs)
  subscriptions_limit = 10
  approval_required   = true
}

# Associate API with Product
resource "azurerm_api_management_product_api" "functions_product_api" {
  api_name            = azurerm_api_management_api.functions_api.name
  product_id          = azurerm_api_management_product.functions_product.product_id
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name
}

# Logger for API Management
resource "azurerm_api_management_logger" "main" {
  name                = "apim-logger"
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name

  application_insights {
    instrumentation_key = azurerm_application_insights.main.instrumentation_key
  }
}

# Diagnostic settings for logging
resource "azurerm_api_management_api_diagnostic" "functions_api_diagnostic" {
  identifier               = "applicationinsights"
  resource_group_name      = azurerm_resource_group.main.name
  api_management_name      = azurerm_api_management.main.name
  api_name                 = azurerm_api_management_api.functions_api.name
  api_management_logger_id = azurerm_api_management_logger.main.id

  sampling_percentage       = 100.0
  always_log_errors         = true
  log_client_ip             = true
  verbosity                 = "information"
  http_correlation_protocol = "W3C"

  frontend_request {
    body_bytes = 8192
    headers_to_log = [
      "content-type",
      "accept",
      "origin"
    ]
  }

  frontend_response {
    body_bytes = 8192
    headers_to_log = [
      "content-type",
      "content-length"
    ]
  }

  backend_request {
    body_bytes = 8192
    headers_to_log = [
      "content-type",
      "accept"
    ]
  }

  backend_response {
    body_bytes = 8192
    headers_to_log = [
      "content-type",
      "content-length"
    ]
  }
}