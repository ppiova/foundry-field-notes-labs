// Foundry Field Notes lab platform: one resource group with the shared platform (infra/platform.bicep) and the labs
// you select (each sample's infra/main.bicep). Deploy-Labs.ps1 creates the sign-in app registration and runs this file
// at subscription scope, so Azure what-if can preview a platform that does not exist yet.
//
// Names follow the Cloud Adoption Framework abbreviations (rg, aif, proj, asp, app, id). Model deployments are named
// after their model, not a lab, because several labs call them.

targetScope = 'subscription'

@description('Resource group for the platform and every lab.')
param resourceGroupName string = 'rg-foundry-field-notes-labs'

@description('Region for every resource. Both models must be offered there for the chosen deployment types.')
param location string = 'eastus2'

@description('Labs to host. Each lab gets its own web app; Lab 001 also gets a Foundry project.')
@allowed(['01', '02'])
@minLength(1)
param labs array = ['01', '02']

@description('Keeps globally unique names (Foundry subdomain, web apps) unique. Derived from the subscription and resource group.')
param suffix string = take(uniqueString(subscription().id, resourceGroupName), 6)

@description('Foundry resource. Pass an existing name to reuse it.')
param foundryAccountName string = 'aif-ffn-labs-${suffix}'

@allowed(['DataZoneStandard', 'GlobalStandard'])
param decisionSku string = 'DataZoneStandard'

@description('Microsoft-Decision-1 requests per minute.')
@minValue(1)
param decisionCapacity int = 50

@description('Chat model for Lab 001\'s agent and Lab 002\'s second opinions. It must support the Responses API with structured outputs.')
param chatModelName string = 'gpt-6-luna'

param chatModelVersion string = '2026-09-22'

@allowed(['DataZoneStandard', 'GlobalStandard'])
param chatSku string = 'DataZoneStandard'

@description('Chat model capacity in thousands of tokens per minute.')
@minValue(1)
param chatCapacity int = 50

@description('F1 is free with daily CPU limits; B1 is billed hourly. Hosting both labs on F1 exceeded its quota in our tests.')
@allowed(['F1', 'B1'])
param appServiceSku string = 'F1'

@description('Client ID of the single-tenant Microsoft Entra app registration used for sign-in.')
param authClientId string

@description('Object IDs of the users allowed to open the apps.')
@minLength(1)
param allowedPrincipalIds array

@description('Optional user object ID that gets Foundry User on the resource, for local live runs and evaluation.')
param developerPrincipalId string = ''

var sharedTags = {
  project: 'foundry-field-notes'
  scope: 'shared'
}
var decisionDeploymentName = 'decision-1'
var chatDeploymentName = chatModelName

resource labsGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: sharedTags
}

module platform 'platform.bicep' = {
  name: 'platform'
  scope: labsGroup
  params: {
    location: location
    foundryAccountName: foundryAccountName
    decisionDeploymentName: decisionDeploymentName
    deployDecisionModel: contains(labs, '02')
    decisionSku: decisionSku
    decisionCapacity: decisionCapacity
    chatDeploymentName: chatDeploymentName
    chatModelName: chatModelName
    chatModelVersion: chatModelVersion
    chatSku: chatSku
    chatCapacity: chatCapacity
    planName: 'asp-ffn-labs'
    appServiceSku: appServiceSku
    signInIdentityName: 'id-ffn-labs-signin'
    developerPrincipalId: developerPrincipalId
    tags: sharedTags
  }
}

module lab01 '../samples/01-support-signal/infra/main.bicep' = if (contains(labs, '01')) {
  name: 'lab01-support-signal'
  scope: labsGroup
  params: {
    location: location
    webAppName: 'app-ffn-lab01-support-signal-${suffix}'
    projectName: 'proj-lab01-support-signal'
    foundryAccountName: platform.outputs.foundryAccountName
    modelDeploymentName: platform.outputs.chatDeploymentName
    planId: platform.outputs.planId
    alwaysOn: appServiceSku != 'F1'
    signInIdentityId: platform.outputs.signInIdentityId
    signInIdentityClientId: platform.outputs.signInIdentityClientId
    authClientId: authClientId
    allowedPrincipalIds: allowedPrincipalIds
  }
}

module lab02 '../samples/02-bid-review-queue/infra/main.bicep' = if (contains(labs, '02')) {
  name: 'lab02-bid-review'
  scope: labsGroup
  params: {
    location: location
    webAppName: 'app-ffn-lab02-bid-review-${suffix}'
    foundryAccountName: platform.outputs.foundryAccountName
    decisionDeploymentName: platform.outputs.decisionDeploymentName
    secondModelDeploymentName: platform.outputs.chatDeploymentName
    secondModelName: chatModelName
    planId: platform.outputs.planId
    alwaysOn: appServiceSku != 'F1'
    signInIdentityId: platform.outputs.signInIdentityId
    signInIdentityClientId: platform.outputs.signInIdentityClientId
    authClientId: authClientId
    allowedPrincipalIds: allowedPrincipalIds
  }
}

output resourceGroupName string = labsGroup.name
output foundryAccountName string = platform.outputs.foundryAccountName
output signInIdentityPrincipalId string = platform.outputs.signInIdentityPrincipalId
// Each module exists exactly when its lab is selected, so the guarded accesses below are never null.
output webApps array = concat(
  contains(labs, '01') ? [{ lab: '01', name: lab01!.outputs.webAppName, hostName: lab01!.outputs.hostName }] : [],
  contains(labs, '02') ? [{ lab: '02', name: lab02!.outputs.webAppName, hostName: lab02!.outputs.hostName }] : []
)
