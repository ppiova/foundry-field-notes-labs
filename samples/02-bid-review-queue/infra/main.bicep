// Lab 002 on the lab platform (infra/main.bicep): the App Service app that only the listed Microsoft Entra users can
// open, and its inference role. The platform owns the Foundry resource, both model deployments, the App Service plan
// and the sign-in identity; this template neither creates nor changes them.

targetScope = 'resourceGroup'

param location string = resourceGroup().location

@description('Web app name; it becomes <name>.azurewebsites.net.')
param webAppName string

param foundryAccountName string

@description('Microsoft-Decision-1 deployment the app calls.')
param decisionDeploymentName string

@description('Chat model deployment that answers second opinions for lines Microsoft-Decision-1 is unsure about.')
param secondModelDeploymentName string

@description('Model name shown on the page and used for the cost estimate.')
param secondModelName string

param planId string

param alwaysOn bool

param signInIdentityId string

param signInIdentityClientId string

@description('Client ID of the single-tenant Microsoft Entra app registration used for sign-in.')
param authClientId string

@description('Object IDs of the users allowed to open the app.')
@minLength(1)
param allowedPrincipalIds array

var tags = {
  project: 'foundry-field-notes'
  lab: '02'
}
var tenantId = subscription().tenantId
// Foundry User (formerly Azure AI User): data actions Microsoft.CognitiveServices/*.
var foundryUserRoleId = '53ca6127-db72-4b80-b1b0-d745d6d5456d'

resource foundry 'Microsoft.CognitiveServices/accounts@2025-06-01' existing = {
  name: foundryAccountName
}

resource site 'Microsoft.Web/sites@2024-04-01' = {
  name: webAppName
  location: location
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: {
      '${signInIdentityId}': {}
    }
  }
  properties: {
    serverFarmId: planId
    httpsOnly: true
    // Blazor Server keeps a session per browser connection.
    clientAffinityEnabled: true
    siteConfig: {
      // Self-contained linux-x64 build, so the app does not depend on the platform's .NET preview runtime.
      linuxFxVersion: 'DOTNETCORE|10.0'
      appCommandLine: './BidReviewQueue'
      webSocketsEnabled: true
      alwaysOn: alwaysOn
      http20Enabled: true
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      appSettings: [
        { name: 'ASPNETCORE_HTTP_PORTS', value: '8080' }
        // The platform sets the Foundry resource's custom subdomain to its name.
        { name: 'FOUNDRY_RESOURCE_ENDPOINT', value: 'https://${foundryAccountName}.services.ai.azure.com' }
        { name: 'FOUNDRY_DECISION_DEPLOYMENT', value: decisionDeploymentName }
        { name: 'FOUNDRY_ESCALATION_DEPLOYMENT', value: secondModelDeploymentName }
        { name: 'FOUNDRY_ESCALATION_MODEL', value: secondModelName }
        { name: 'FOUNDRY_CREDENTIAL', value: 'managed-identity' }
        { name: 'OVERRIDE_USE_MI_FIC_ASSERTION_CLIENTID', value: signInIdentityClientId }
        { name: 'WEBSITE_AUTH_AAD_ALLOWED_TENANTS', value: tenantId }
        { name: 'SCM_DO_BUILD_DURING_DEPLOYMENT', value: 'false' }
      ]
    }
  }
  tags: tags
}

// Sign-in is required for every request, including /api; only allowedPrincipalIds get through.
resource auth 'Microsoft.Web/sites/config@2024-04-01' = {
  parent: site
  name: 'authsettingsV2'
  properties: {
    platform: {
      enabled: true
    }
    globalValidation: {
      requireAuthentication: true
      unauthenticatedClientAction: 'RedirectToLoginPage'
      redirectToProvider: 'azureactivedirectory'
    }
    identityProviders: {
      azureActiveDirectory: {
        enabled: true
        registration: {
          clientId: authClientId
          clientSecretSettingName: 'OVERRIDE_USE_MI_FIC_ASSERTION_CLIENTID'
          openIdIssuer: '${environment().authentication.loginEndpoint}${tenantId}/v2.0'
        }
        validation: {
          allowedAudiences: [
            'api://${authClientId}'
          ]
          defaultAuthorizationPolicy: {
            allowedPrincipals: {
              identities: allowedPrincipalIds
            }
          }
        }
      }
    }
    login: {
      tokenStore: {
        enabled: false
      }
    }
    httpSettings: {
      requireHttps: true
    }
  }
}

resource appCanDecide 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(foundry.id, site.id, foundryUserRoleId)
  scope: foundry
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', foundryUserRoleId)
    principalId: site.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output webAppName string = site.name
output hostName string = site.properties.defaultHostName
