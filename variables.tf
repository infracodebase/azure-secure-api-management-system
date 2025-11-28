variable "environment" {
  type        = string
  description = "Environment name (e.g., dev, staging, prod)"
  default     = "dev"
}

variable "location" {
  type        = string
  description = "Azure region where resources will be created"
  default     = "East US"
}

variable "project_name" {
  type        = string
  description = "Name of the project, used as prefix for resources"
  default     = "apiplatform"
}

variable "apim_sku" {
  type        = string
  description = "SKU for API Management (Developer, Basic, Standard, Premium)"
  default     = "Developer"
}

variable "apim_capacity" {
  type        = number
  description = "Capacity for API Management"
  default     = 1

  validation {
    condition     = var.apim_capacity >= 1
    error_message = "API Management capacity must be at least 1."
  }
}

variable "functions_sku" {
  type        = string
  description = "SKU for Functions App Service Plan (Y1, EP1, EP2, EP3, P1v2, P2v2, P3v2)"
  default     = "Y1"
}

variable "publisher_name" {
  type        = string
  description = "Publisher name for API Management"
  default     = "Your Organization"
}

variable "publisher_email" {
  type        = string
  description = "Publisher email for API Management"
  default     = "admin@yourorg.com"
}