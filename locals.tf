locals {
  # Resource naming convention
  resource_prefix = "${var.project_name}-${var.environment}"

  # Common tags
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }

  # Network configuration
  # Security Note: Proper network segmentation for defense in depth
  vnet_address_space                = ["10.0.0.0/16"]
  apim_subnet_prefix                = "10.0.1.0/24"
  functions_subnet_prefix           = "10.0.2.0/24"
  private_endpoint_subnet_prefix    = "10.0.3.0/24"
  application_gateway_subnet_prefix = "10.0.4.0/24"
}