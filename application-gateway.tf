# Application Gateway with Web Application Firewall
# Security Note: Provides L7 load balancing and WAF protection for APIM
# Compliance: Azure APIM Security Baseline Rule 4 - Deploy WAF for critical APIs

# Public IP for Application Gateway
resource "azurerm_public_ip" "appgw" {
  name                = "pip-appgw-${local.resource_prefix}-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

# Subnet for Application Gateway
resource "azurerm_subnet" "appgw" {
  name                 = "subnet-appgw"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [local.application_gateway_subnet_prefix]
}

# Network Security Group for Application Gateway
resource "azurerm_network_security_group" "appgw" {
  name                = "nsg-appgw-${local.resource_prefix}-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags

  # Allow HTTPS inbound
  security_rule {
    name                       = "Allow_HTTPS_Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  # Allow HTTP inbound for redirect
  security_rule {
    name                       = "Allow_HTTP_Inbound"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  # Allow Application Gateway infrastructure
  security_rule {
    name                       = "Allow_GatewayManager"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "65200-65535"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }
}

# Associate NSG to Application Gateway subnet
resource "azurerm_subnet_network_security_group_association" "appgw" {
  subnet_id                 = azurerm_subnet.appgw.id
  network_security_group_id = azurerm_network_security_group.appgw.id
}

# Web Application Firewall Policy
resource "azurerm_web_application_firewall_policy" "main" {
  name                = "waf-policy-${local.resource_prefix}-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.common_tags

  # Security Note: Prevention mode blocks malicious requests
  # Detection mode would only log without blocking
  policy_settings {
    enabled                     = true
    mode                        = "Prevention"
    request_body_check          = true
    file_upload_limit_in_mb     = 100
    max_request_body_size_in_kb = 128
  }

  # OWASP Core Rule Set for comprehensive protection
  # Security Note: Protects against OWASP Top 10 vulnerabilities
  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }
  }
}

# Application Gateway with WAF
resource "azurerm_application_gateway" "main" {
  name                = "appgw-${local.resource_prefix}-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.common_tags

  # Enable WAF
  # Security Note: WAF provides protection against web application attacks
  # Compliance: Azure APIM Security Baseline Rule 4
  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 1
  }

  # Associate WAF policy
  firewall_policy_id = azurerm_web_application_firewall_policy.main.id

  gateway_ip_configuration {
    name      = "appGatewayIpConfig"
    subnet_id = azurerm_subnet.appgw.id
  }

  frontend_port {
    name = "frontend-port-80"
    port = 80
  }

  frontend_port {
    name = "frontend-port-443"
    port = 443
  }

  frontend_ip_configuration {
    name                 = "appGatewayFrontendIP"
    public_ip_address_id = azurerm_public_ip.appgw.id
  }

  # Backend pool pointing to APIM
  backend_address_pool {
    name  = "apim-backend-pool"
    fqdns = [azurerm_api_management.main.gateway_url]
  }

  # Backend HTTP settings for APIM
  backend_http_settings {
    name                  = "apim-backend-http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 443
    protocol              = "Https"
    request_timeout       = 60
    host_name             = azurerm_api_management.main.gateway_url

    # Security Note: Validates backend certificates for secure communication
    trusted_root_certificate_names = []
    probe_name                     = "apim-probe"
  }

  # Health probe for APIM
  probe {
    name                                      = "apim-probe"
    protocol                                  = "Https"
    path                                      = "/status-0123456789abcdef"
    host                                      = azurerm_api_management.main.gateway_url
    interval                                  = 30
    timeout                                   = 30
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = false

    match {
      status_code = ["200-399"]
    }
  }

  # HTTP listener (for redirect to HTTPS)
  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "appGatewayFrontendIP"
    frontend_port_name             = "frontend-port-80"
    protocol                       = "Http"
  }

  # HTTPS listener
  http_listener {
    name                           = "https-listener"
    frontend_ip_configuration_name = "appGatewayFrontendIP"
    frontend_port_name             = "frontend-port-443"
    protocol                       = "Https"
    ssl_certificate_name           = "appgw-ssl-cert"
  }

  # Self-signed certificate for demonstration
  # Security Note: Replace with proper certificate from Key Vault in production
  ssl_certificate {
    name     = "appgw-ssl-cert"
    data     = base64encode(tls_private_key.appgw_cert.private_key_pem)
    password = ""
  }

  # Routing rule - redirect HTTP to HTTPS
  request_routing_rule {
    name                        = "http-redirect-rule"
    rule_type                   = "Basic"
    http_listener_name          = "http-listener"
    redirect_configuration_name = "https-redirect"
    priority                    = 100
  }

  # Routing rule - HTTPS to APIM
  request_routing_rule {
    name                       = "https-routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "https-listener"
    backend_address_pool_name  = "apim-backend-pool"
    backend_http_settings_name = "apim-backend-http-settings"
    priority                   = 200
  }

  # Redirect configuration
  redirect_configuration {
    name                 = "https-redirect"
    redirect_type        = "Permanent"
    target_listener_name = "https-listener"
    include_path         = true
    include_query_string = true
  }

  # Security Note: Enable autoscaling for production workloads
  autoscale_configuration {
    min_capacity = 1
    max_capacity = 3
  }
}

# Generate self-signed certificate for demonstration
# Security Note: Replace with proper certificate management in production
resource "tls_private_key" "appgw_cert" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "appgw_cert" {
  private_key_pem = tls_private_key.appgw_cert.private_key_pem

  subject {
    common_name  = "api.${var.project_name}.local"
    organization = var.publisher_name
  }

  validity_period_hours = 8760 # 1 year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}