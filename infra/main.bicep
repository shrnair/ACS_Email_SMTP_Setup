// ============================================================
// Bicep Template: ACS Email Demo Infrastructure
// Provisions all Azure resources needed for the full-stack app.
// ============================================================

@description('Short prefix for naming resources (lowercase, no special chars)')
@minLength(3)
@maxLength(12)
param projectPrefix string = 'acsemail'

@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Custom email domain (e.g., notifications.contoso.com). Must be a domain you own.')
param customEmailDomain string

@description('Sender username (mailbox before @, e.g., noreply)')
param senderUsername string = 'noreply'

// ---- Derived names ----
var uniqueSuffix = uniqueString(resourceGroup().id)
var communicationServiceName = '${projectPrefix}-acs-${uniqueSuffix}'
var emailServiceName = '${projectPrefix}-email-${uniqueSuffix}'
var appServicePlanName = '${projectPrefix}-plan-${uniqueSuffix}'
var backendAppName = '${projectPrefix}-api-${uniqueSuffix}'
var frontendAppName = '${projectPrefix}-web-${uniqueSuffix}'
var senderAddress = '${senderUsername}@${customEmailDomain}'

// ============================================================
// Communication Services Resource
// ============================================================
resource communicationService 'Microsoft.Communication/communicationServices@2023-04-01' = {
  name: communicationServiceName
  location: 'global'
  properties: {
    dataLocation: 'unitedstates'
  }
}

// ============================================================
// Email Communication Services Resource
// ============================================================
resource emailService 'Microsoft.Communication/emailServices@2023-04-01' = {
  name: emailServiceName
  location: 'global'
  properties: {
    dataLocation: 'unitedstates'
  }
}

// ============================================================
// Custom Email Domain (will require manual DNS verification)
// ============================================================
resource customDomain 'Microsoft.Communication/emailServices/domains@2023-04-01' = {
  parent: emailService
  name: customEmailDomain
  location: 'global'
  properties: {
    domainManagement: 'CustomerManaged'
    userEngagementTracking: 'Disabled'
  }
}

// ============================================================
// Sender Username (MailFrom address)
// ============================================================
resource senderUsernameResource 'Microsoft.Communication/emailServices/domains/senderUsernames@2023-04-01' = {
  parent: customDomain
  name: senderUsername
  properties: {
    username: senderUsername
    displayName: 'No Reply'
  }
}

// ============================================================
// Link the custom domain to the Communication Services resource
// ============================================================
resource domainLink 'Microsoft.Communication/communicationServices/domains@2023-04-01' = {
  parent: communicationService
  name: customEmailDomain
  properties: {
    domainResourceId: customDomain.id
  }
}

// ============================================================
// App Service Plan (shared by frontend and backend)
// ============================================================
resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: 'B1'
    tier: 'Basic'
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

// ============================================================
// Backend Web App (Node.js API)
// ============================================================
resource backendApp 'Microsoft.Web/sites@2023-01-01' = {
  name: backendAppName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'NODE|18-lts'
      appSettings: [
        {
          name: 'ACS_ENDPOINT'
          value: 'https://${communicationServiceName}.communication.azure.com'
        }
        {
          name: 'ACS_SENDER_ADDRESS'
          value: senderAddress
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~18'
        }
      ]
      cors: {
        allowedOrigins: [
          'https://${frontendAppName}.azurewebsites.net'
        ]
      }
    }
    httpsOnly: true
  }
}

// ============================================================
// Frontend Web App (Static HTML/JS/CSS)
// ============================================================
resource frontendApp 'Microsoft.Web/sites@2023-01-01' = {
  name: frontendAppName
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'NODE|18-lts'
      appSettings: [
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~18'
        }
      ]
    }
    httpsOnly: true
  }
}

// ============================================================
// RBAC: Grant backend managed identity "Contributor" on ACS
// This allows the backend to send emails via managed identity.
// ============================================================
var contributorRoleId = 'b24988ac-6180-42a0-ab88-20f7382dd24c'

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(backendApp.id, communicationService.id, contributorRoleId)
  scope: communicationService
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', contributorRoleId)
    principalId: backendApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// ============================================================
// Outputs
// ============================================================
output communicationServiceName string = communicationService.name
output communicationServiceEndpoint string = 'https://${communicationServiceName}.communication.azure.com'
output emailServiceName string = emailService.name
output customDomainName string = customDomain.name
output senderAddress string = senderAddress
output backendAppName string = backendApp.name
output backendUrl string = 'https://${backendAppName}.azurewebsites.net'
output frontendAppName string = frontendApp.name
output frontendUrl string = 'https://${frontendAppName}.azurewebsites.net'
output backendPrincipalId string = backendApp.identity.principalId
