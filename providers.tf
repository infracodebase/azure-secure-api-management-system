provider "azurerm" {
  # Security Note: Uses Azure CLI authentication with service principal
  # Already authenticated via az login with service principal credentials
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}

provider "random" {}