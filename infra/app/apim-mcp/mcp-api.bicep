@description('The name of the API Management service')
param apimServiceName string

@description('The name of the App Service hosting the MCP endpoints')
param webAppName string

@description('The ID of the MCP Entra application')
param mcpAppId string

@description('The tenant ID of the MCP Entra application')
param mcpAppTenantId string

// Get reference to the existing APIM service
resource apimService 'Microsoft.ApiManagement/service@2023-05-01-preview' existing = {
  name: apimServiceName
}

// Get reference to the App Service (Web App)
resource webApp 'Microsoft.Web/sites@2023-12-01' existing = {
  name: webAppName
}


// Create or update named values for MCP OAuth configuration
resource mcpTenantIdNamedValue 'Microsoft.ApiManagement/service/namedValues@2021-08-01' = {
  parent: apimService
  name: 'McpTenantId'
  properties: {
    displayName: 'McpTenantId'
    value: mcpAppTenantId
    secret: false
  }
}

resource mcpClientIdNamedValue 'Microsoft.ApiManagement/service/namedValues@2021-08-01' = {
  parent: apimService
  name: 'McpClientId'
  properties: {
    displayName: 'McpClientId'
    value: mcpAppId
    secret: false
  }
}

// Create or update the APIM Gateway URL named value
resource APIMGatewayURLNamedValue 'Microsoft.ApiManagement/service/namedValues@2021-08-01' = {
  parent: apimService
  name: 'APIMGatewayURL'
  properties: {
    displayName: 'APIMGatewayURL'
    value: apimService.properties.gatewayUrl
    secret: false
  }
}



// Create the MCP API definition in APIM
resource mcpApi 'Microsoft.ApiManagement/service/apis@2023-05-01-preview' = {
  parent: apimService
  name: 'mcp'
  properties: {
    displayName: 'MCP API'
    description: 'Model Context Protocol API endpoints'
    subscriptionRequired: false
    path: 'mcp'
    protocols: [
      'https'
    ]
    serviceUrl: 'https://${webApp.properties.defaultHostName}/'
  }
}

// Apply policy at the API level for all operations
resource mcpApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2023-05-01-preview' = {
  parent: mcpApi
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: loadTextContent('mcp-api.policy.xml')
  }
  dependsOn: [
    APIMGatewayURLNamedValue
    mcpTenantIdNamedValue
    mcpClientIdNamedValue
  ]
}

// Create the SSE endpoint operation
resource mcpSseOperation 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  parent: mcpApi
  name: 'mcp-sse'
  properties: {
    displayName: 'MCP SSE Endpoint'
    method: 'GET'
    urlTemplate: '/sse'
    description: 'Server-Sent Events endpoint for MCP Server'
  }
}

// Create the message endpoint operation
resource mcpMessageOperation 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  parent: mcpApi
  name: 'mcp-message'
  properties: {
    displayName: 'MCP Message Endpoint'
    method: 'POST'
    urlTemplate: '/message'
    description: 'Message endpoint for MCP Server'
  }
}

// Create the MCP Streamable HTTP protocol endpoints
resource mcpStreamableGetOperation 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  parent: mcpApi
  name: 'mcp-streamable-get'
  properties: {
    displayName: 'MCP Streamable GET Endpoint'
    method: 'GET'
    urlTemplate: '/'
    description: 'Streamable GET endpoint for MCP Server'
  }
}

resource mcpStreamablePostOperation 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  parent: mcpApi
  name: 'mcp-streamable-post'
  properties: {
    displayName: 'MCP Streamable POST Endpoint'
    method: 'POST'
    urlTemplate: '/'
    description: 'Streamable POST endpoint for MCP Server'
  }
}

// Create the PRM (Protected Resource Metadata) endpoint - RFC 9728
resource mcpPrmOperation 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  parent: mcpApi
  name: 'mcp-prm'
  properties: {
    displayName: 'Protected Resource Metadata'
    method: 'GET'
    urlTemplate: '/prm'
    description: 'Protected Resource Metadata endpoint (RFC 9728)'
  }
}

// Apply specific policy for the PRM endpoint (anonymous access)
resource mcpPrmPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2023-05-01-preview' = {
  parent: mcpPrmOperation
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: loadTextContent('mcp-prm.policy.xml')
  }
  dependsOn: [
    APIMGatewayURLNamedValue
    mcpTenantIdNamedValue
    mcpClientIdNamedValue
  ]
}

// Output the API ID for reference
output apiId string = mcpApi.id
output mcpAppId string = mcpAppId
output mcpAppTenantId string = mcpAppTenantId
