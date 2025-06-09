targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string


@minLength(1)
@description('Primary location for all resources')
@allowed(['australiaeast', 'eastasia', 'eastus', 'eastus2', 'northeurope', 'southcentralus', 'southeastasia', 'swedencentral', 'uksouth', 'westus2', 'eastus2euap'])
@metadata({
  azd: {
    type: 'location'
  }
})
param location string
param apiServiceName string = ''
param applicationInsightsName string = ''
param appServicePlanName string = ''
param logAnalyticsName string = ''
param resourceGroupName string = ''
param mcpEntraApplicationDisplayName string = ''
param mcpEntraApplicationUniqueName string = ''
param disableLocalAuth bool = true

// MCP Client APIM gateway specific variables


var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }
var webAppName = !empty(apiServiceName) ? apiServiceName : '${abbrs.webSitesAppService}api-${resourceToken}'


// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

var apimResourceToken = toLower(uniqueString(subscription().id, resourceGroupName, environmentName, location))
var apiManagementName = '${abbrs.apiManagementService}${apimResourceToken}'

// apim service deployment
module apimService './core/apim/apim.bicep' = {
  name: apiManagementName
  scope: rg
  params:{
    apiManagementName: apiManagementName
  }
}

// User assigned identity for MCP
module mcpUserAssignedIdentity './core/identity/userAssignedIdentity.bicep' = {
  name: 'mcpUserAssignedIdentity'
  scope: rg
  params: {
    identityName: '${apiManagementName}-mcp-identity'
    location: location
    tags: tags
  }
}

// MCP Entra App - moved from mcp-api.bicep to avoid circular dependency
module mcpEntraApp './app/apim-mcp/mcp-entra-app.bicep' = {
  name: 'mcpEntraAppDeployment'
  scope: rg
  params: {
    mcpAppUniqueName: !empty(mcpEntraApplicationUniqueName) ? mcpEntraApplicationUniqueName : 'mcp-api-${apimResourceToken}'
    mcpAppDisplayName: !empty(mcpEntraApplicationDisplayName) ? mcpEntraApplicationDisplayName : 'MCP-API-${apimResourceToken}'
    userAssignedIdentityPrincipleId: mcpUserAssignedIdentity.outputs.identityPrincipalId
  }
}

// MCP server API endpoints
module mcpApiModule './app/apim-mcp/mcp-api.bicep' = {
  name: 'mcpApiModule'
  scope: rg
  params: {
    apimServiceName: apimService.name
    webAppName: webAppName
    mcpAppId: mcpEntraApp.outputs.mcpAppId
    mcpAppTenantId: mcpEntraApp.outputs.mcpAppTenantId
  }
  dependsOn: [
    appServicePlan
  ]
}


// The application backend is a function app
module appServicePlan './core/host/appserviceplan.bicep' = {
  name: 'appserviceplan'
  scope: rg
  params: {
    name: !empty(appServicePlanName) ? appServicePlanName : '${abbrs.webServerFarms}${resourceToken}'
    location: location
    tags: tags
    sku: {
      name: 'B1'
      capacity: 1
    }
  }
}

module apiWebApp './app/api.bicep' = {
  name: 'apiWebApp'
  scope: rg
  params: {
    name: webAppName
    location: location
    tags: tags
    appServicePlanId: appServicePlan.outputs.id
    mcpClientId: mcpEntraApp.outputs.mcpAppId
    mcpTenantId: mcpEntraApp.outputs.mcpAppTenantId
    managedIdentityClientId: mcpUserAssignedIdentity.outputs.identityClientId
    userAssignedIdentityId: mcpUserAssignedIdentity.outputs.identityId
  }
}

// Monitor application with Azure Monitor
module monitoring './core/monitor/monitoring.bicep' = {
  name: 'monitoring'
  scope: rg
  params: {
    location: location
    tags: tags
    logAnalyticsName: !empty(logAnalyticsName) ? logAnalyticsName : '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    applicationInsightsName: !empty(applicationInsightsName) ? applicationInsightsName : '${abbrs.insightsComponents}${resourceToken}'
    disableLocalAuth: disableLocalAuth  
  }
}

var monitoringRoleDefinitionId = '3913510d-42f4-4e42-8a64-420c390055eb' // Monitoring Metrics Publisher role ID

// Allow access from api to application insights using a managed identity
module appInsightsRoleAssignmentApi './core/monitor/appinsights-access.bicep' = {
  name: 'appInsightsRoleAssignmentapi'
  scope: rg
  params: {
    appInsightsName: monitoring.outputs.applicationInsightsName
    roleDefinitionID: monitoringRoleDefinitionId
    principalID: mcpUserAssignedIdentity.outputs.identityPrincipalId
  }
}

// App outputs
output APPLICATIONINSIGHTS_CONNECTION_STRING string = monitoring.outputs.applicationInsightsConnectionString
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output SERVICE_API_NAME string = apiWebApp.outputs.SERVICE_API_NAME
output WEBAPP_NAME string = apiWebApp.outputs.SERVICE_API_NAME
output SERVICE_API_ENDPOINTS array = ['${apimService.outputs.gatewayUrl}/mcp/']
