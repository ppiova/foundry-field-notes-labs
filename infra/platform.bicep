// What every lab shares: the Microsoft Foundry resource and its model deployments, the App Service plan, and the
// managed identity that App Service sign-in uses instead of a client secret. infra/main.bicep deploys this module.

targetScope = 'resourceGroup'

param location string

@description('Foundry resource (kind AIServices). Its custom subdomain uses the same name.')
param foundryAccountName string

@description('Microsoft-Decision-1 deployment name.')
param decisionDeploymentName string

@description('Deploy Microsoft-Decision-1. Only Lab 002 calls it; leaving it out never deletes an existing deployment.')
param deployDecisionModel bool = true

@allowed(['DataZoneStandard', 'GlobalStandard'])
param decisionSku string

@description('Requests per minute. A rate limit that uses quota, not a charge.')
@minValue(1)
param decisionCapacity int

@description('Chat model deployment name. Lab 001 runs its agent on it; Lab 002 asks it for second opinions.')
param chatDeploymentName string

param chatModelName string

param chatModelVersion string

@allowed(['DataZoneStandard', 'GlobalStandard'])
param chatSku string

@description('Thousands of tokens per minute. A rate limit that uses quota, not a charge.')
@minValue(1)
param chatCapacity int

param planName string

@description('F1 is free with daily CPU limits; B1 is billed hourly.')
@allowed(['F1', 'B1'])
param appServiceSku string

param signInIdentityName string

@description('Optional user object ID that gets Foundry User on the resource, for local live runs and evaluation.')
param developerPrincipalId string = ''

param tags object

// Foundry User (formerly Azure AI User): data actions Microsoft.CognitiveServices/*.
var foundryUserRoleId = '53ca6127-db72-4b80-b1b0-d745d6d5456d'

resource foundry 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
  name: foundryAccountName
  location: location
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    customSubDomainName: foundryAccountName
    publicNetworkAccess: 'Enabled'
    // Microsoft Entra ID only: no API keys.
    disableLocalAuth: true
    allowProjectManagement: true
  }
  tags: tags
}

resource decision 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = if (deployDecisionModel) {
  parent: foundry
  name: decisionDeploymentName
  sku: {
    name: decisionSku
    capacity: decisionCapacity
  }
  properties: {
    model: {
      format: 'Microsoft'
      name: 'Microsoft-Decision-1'
      version: '1'
    }
  }
}

// Deployments on one Foundry resource are created one at a time.
resource chat 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = {
  parent: foundry
  name: chatDeploymentName
  sku: {
    name: chatSku
    capacity: chatCapacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: chatModelName
      version: chatModelVersion
    }
  }
  dependsOn: [
    decision
  ]
}

resource plan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: planName
  location: location
  kind: 'linux'
  sku: {
    name: appServiceSku
  }
  properties: {
    reserved: true
  }
  tags: tags
}

// Used only as the sign-in client credential (federated identity credential), never for anything else.
resource signInIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: signInIdentityName
  location: location
  tags: tags
}

resource developerCanUseModels 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(developerPrincipalId)) {
  name: guid(foundry.id, developerPrincipalId, foundryUserRoleId)
  scope: foundry
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', foundryUserRoleId)
    principalId: developerPrincipalId
    principalType: 'User'
  }
}

output foundryAccountName string = foundry.name
output decisionDeploymentName string = decisionDeploymentName
output chatDeploymentName string = chat.name
output planId string = plan.id
output signInIdentityId string = signInIdentity.id
output signInIdentityClientId string = signInIdentity.properties.clientId
output signInIdentityPrincipalId string = signInIdentity.properties.principalId
