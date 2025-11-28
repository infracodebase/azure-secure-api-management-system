# Azure API Management + Functions Python API System

This infrastructure creates a secure API system using Azure API Management integrated with Azure Functions running Python code.

## Architecture Overview

- **Azure API Management**: Provides API gateway functionality with security, rate limiting, and monitoring
- **Azure Functions**: Serverless compute running Python functions
- **Azure Key Vault**: Secure storage for secrets and certificates
- **Virtual Network**: Network isolation and security
- **Private Endpoints**: Secure connectivity without public internet exposure
- **Application Insights**: Monitoring and logging

## Security Features

✅ **Network Security**:
- Virtual Network with proper subnets and NSGs
- Private endpoints for secure connectivity
- Internal API Management mode
- No public access to Functions

✅ **Identity & Access**:
- Managed identities for authentication
- Azure RBAC for least privilege access
- Key Vault integration for secrets

✅ **API Security**:
- HTTPS-only communication
- Rate limiting and IP filtering
- Subscription-based access control
- Comprehensive logging

## Prerequisites

1. **Azure CLI** installed and authenticated
2. **Terraform** >= 1.13 installed
3. Required Azure permissions:
   - Contributor access to the subscription
   - Ability to create service principals and assign roles

## Deployment Steps

### 1. Set Required Variables

Create a `terraform.tfvars` file:

```hcl
environment      = "dev"
location        = "East US"
project_name    = "myapi"
publisher_name  = "Your Organization"
publisher_email = "admin@yourorg.com"
apim_sku       = "Developer"  # Use Standard/Premium for production
```

### 2. Initialize and Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Plan the deployment
terraform plan

# Apply the infrastructure
terraform apply
```

### 3. Deploy Function Code

After infrastructure deployment, deploy the Python function code:

```bash
# Get function app name from Terraform output
FUNCTION_APP_NAME=$(terraform output -raw function_app_name)

# Install Azure Functions Core Tools if not already installed
npm install -g azure-functions-core-tools@4

# Navigate to function code directory
cd function_code

# Deploy functions
func azure functionapp publish $FUNCTION_APP_NAME --python
```

### 4. Configure API Management Function Key

Get the function key and update API Management:

```bash
# Get function key
az functionapp function keys list \
  --function-name hello \
  --name $FUNCTION_APP_NAME \
  --resource-group $(terraform output -raw resource_group_name)

# Update the named value in API Management with the actual function key
```

## API Endpoints

The API provides the following endpoints through API Management:

### GET /api/hello
Returns a greeting message.

**Query Parameters:**
- `name` (optional): Name to include in greeting

**Example:**
```bash
curl -X GET "https://your-apim.azure-api.net/api/hello?name=Justin" \
  -H "Ocp-Apim-Subscription-Key: YOUR_SUBSCRIPTION_KEY"
```

### POST /api/process
Processes JSON data sent in the request body.

**Request Body:** JSON object with data to process

**Example:**
```bash
curl -X POST "https://your-apim.azure-api.net/api/process" \
  -H "Content-Type: application/json" \
  -H "Ocp-Apim-Subscription-Key: YOUR_SUBSCRIPTION_KEY" \
  -d '{"name": "Justin", "value": 42}'
```

## Monitoring and Logs

- **Application Insights**: View function execution logs and performance metrics
- **API Management Analytics**: Monitor API usage and response times
- **Azure Monitor**: Centralized logging and alerting

## Production Considerations

### Security Hardening

1. **Change API Management SKU** to Standard or Premium for production
2. **Configure custom domains** with proper SSL certificates
3. **Implement OAuth 2.0** or other advanced authentication
4. **Review and tighten IP filtering** rules
5. **Enable Azure Defender** for all services

### Performance and Scaling

1. **Use Premium Functions plan** for better performance
2. **Configure auto-scaling** for API Management
3. **Implement caching** strategies
4. **Set up Azure CDN** for static content

### Operational

1. **Set up monitoring alerts**
2. **Configure backup strategies**
3. **Implement CI/CD pipelines**
4. **Document API specifications** using OpenAPI/Swagger

## Cleanup

To remove all resources:

```bash
terraform destroy
```

## Cost Optimization

- Use Consumption plan for Functions in development
- Monitor API Management usage and adjust capacity
- Set up budget alerts
- Use Azure Advisor recommendations

## Support and Documentation

- [Azure API Management Documentation](https://docs.microsoft.com/azure/api-management/)
- [Azure Functions Python Guide](https://docs.microsoft.com/azure/azure-functions/functions-reference-python)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)