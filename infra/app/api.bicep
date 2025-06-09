param name string
param location string = resourceGroup().location
param tags object = {}
param appServicePlanId string
param serviceName string = 'api'

// MCP Configuration Parameters
param mcpClientId string = ''
param mcpTenantId string = ''
param managedIdentityClientId string = ''
param userAssignedIdentityId string = ''

resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: name
  location: location
  tags: union(tags, { 'azd-service-name': serviceName })
  kind: 'app'
  identity: !empty(userAssignedIdentityId) ? {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  } : null
  properties: {
    serverFarmId: appServicePlanId
    siteConfig: {
      appSettings: [
        // Azure AD Configuration (matches appsettings.json structure)
        {
          name: 'AzureAd__TenantId'
          value: mcpTenantId
        }
        {
          name: 'AzureAd__ClientId'
          value: mcpClientId
        }
        {
          name: 'AzureAd__ManagedIdentityClientId'
          value: managedIdentityClientId
        }
      ]
      linuxFxVersion: 'DOTNETCORE|8.0'
    }
  }
}

output SERVICE_API_NAME string = webApp.name
