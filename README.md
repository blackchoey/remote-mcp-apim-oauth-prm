# MCP Servers authorization with Protected Resource Metadata (PRM) sample 

A complete sample implementation of a Model Context Protocol (MCP) server that demonstrates secure authorization using Protected Resource Metadata (PRM) and Microsoft Graph API integration.

## Overview

This sample implements the latest draft version of [MCP Authorization specification](https://modelcontextprotocol.io/specification/draft/basic/authorization) with Protected Resource Metadata (PRM), which simplifies the authorization implementation a lot. The server is built with ASP.NET Core and deployed to Azure with full infrastructure automation.

## Key Features

- **🔐 Latest MCP Authorization**: Implements MCP Authorization with Protected Resource Metadata (PRM)
- **🚀 Zero-Config Deployment**: Complete infrastructure setup with a single command
- **🔑 Secure by Design**: Uses Managed Identity as Federated Identity Credential (no client secrets)
- **📊 Microsoft Graph Access**: Demonstrates accessing protected resources with user-delegated permissions

## Prerequisites

- [Azure Developer CLI (azd)](https://aka.ms/azd) v1.17 or above
- Azure subscription
- VS Code (for testing)

## Quick Start

### 1. Deploy to Azure

Deploy the complete solution to Azure with a single command:

```shell
azd up
```

This will provision:
- Azure API Management service
- App Service with the MCP server
- Microsoft Entra App
- Managed Identity as federated credential
- Application Insights for monitoring
- All necessary configuration

### 2. Test with VS Code

1. **Install latest VS Code**
2. **Add MCP Server**:
   - Open Command Palette (`Ctrl+Shift+P`)
   - Run `MCP: Add Server`
   - Select `HTTP` as the server type
   - Enter the endpoint URL from the `azd up` output:
   
   ![azd up result](azdup.png)

3. **Authorize and Test**:
   - After a while, VS Code will prompt you to sign in to Microsoft
   - After authentication, open GitHub Copilot
   - Ask: "Who am I?" - Copilot will use the MCP server to retrieve your profile
   - If consent is required, you'll receive a message with a login URL to visit
   - After visiting the URL and consenting, try the request again in GitHub Copilot

### MCP Tools

The sample includes one MCP tool:

- **`ShowUserProfile`**: Retrieves the current user's profile information from Microsoft Graph, including display name, email, job title, and department.
