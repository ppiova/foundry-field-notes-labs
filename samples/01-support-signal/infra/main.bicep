// Lab 001 on the lab platform (infra/main.bicep): a Foundry project, the web app with restricted Microsoft Entra
// sign-in, and its inference role. The platform owns the Foundry resource, the model deployment, the App Service plan
// and the sign-in identity; this template neither creates nor changes them.
targetScope = 'resourceGroup'
param location string = resourceGroup().location
param webAppName string
param projectName string
param foundryAccountName string
param modelDeploymentName string
param planId string
param alwaysOn bool
param signInIdentityId string
param signInIdentityClientId string
param authClientId string
@minLength(1)
param allowedPrincipalIds array
var tags = { project: 'foundry-field-notes', lab: '01' }

resource foundry 'Microsoft.CognitiveServices/accounts@2025-06-01' existing = { name: foundryAccountName }
resource project 'Microsoft.CognitiveServices/accounts/projects@2025-06-01' = {
  parent: foundry
  name: projectName
  location: location
  identity: { type: 'SystemAssigned' }
  properties: { displayName: 'Lab 001 Support Signal', description: 'Lab 001: reviewable support triage with Microsoft Agent Framework.' }
  tags: tags
}
// The platform sets the Foundry resource's custom subdomain to its name.
var projectEndpoint = 'https://${foundryAccountName}.services.ai.azure.com/api/projects/${projectName}'

resource site 'Microsoft.Web/sites@2024-04-01' = {
  name: webAppName
  location: location
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: { '${signInIdentityId}': {} }
  }
  properties: {
    serverFarmId: planId
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'DOTNETCORE|10.0'
      appCommandLine: './SupportSignal'
      alwaysOn: alwaysOn
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      appSettings: [
        { name: 'ASPNETCORE_HTTP_PORTS', value: '8080' }
        { name: 'FOUNDRY_PROJECT_ENDPOINT', value: projectEndpoint }
        { name: 'FOUNDRY_MODEL', value: modelDeploymentName }
        { name: 'FOUNDRY_CREDENTIAL', value: 'managed-identity' }
        { name: 'SUPPORT_SIGNAL_LIVE_ONLY', value: 'true' }
        { name: 'OVERRIDE_USE_MI_FIC_ASSERTION_CLIENTID', value: signInIdentityClientId }
        { name: 'WEBSITE_AUTH_AAD_ALLOWED_TENANTS', value: subscription().tenantId }
        { name: 'SCM_DO_BUILD_DURING_DEPLOYMENT', value: 'false' }
      ]
    }
  }
  tags: tags
  dependsOn: [project]
}
resource auth 'Microsoft.Web/sites/config@2024-04-01' = {
  parent: site
  name: 'authsettingsV2'
  properties: {
    platform: { enabled: true }
    globalValidation: { requireAuthentication: true, unauthenticatedClientAction: 'RedirectToLoginPage', redirectToProvider: 'azureactivedirectory' }
    identityProviders: {
      azureActiveDirectory: {
        enabled: true
        registration: {
          clientId: authClientId
          clientSecretSettingName: 'OVERRIDE_USE_MI_FIC_ASSERTION_CLIENTID'
          openIdIssuer: '${environment().authentication.loginEndpoint}${subscription().tenantId}/v2.0'
        }
        validation: {
          allowedAudiences: ['api://${authClientId}']
          defaultAuthorizationPolicy: { allowedPrincipals: { identities: allowedPrincipalIds } }
        }
      }
    }
    login: { tokenStore: { enabled: false } }
    httpSettings: { requireHttps: true }
  }
}
var role = '53ca6127-db72-4b80-b1b0-d745d6d5456d'
resource inferenceRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(foundry.id, site.id, role)
  scope: foundry
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role)
    principalId: site.identity.principalId
    principalType: 'ServicePrincipal'
  }
}
output webAppName string = site.name
output hostName string = site.properties.defaultHostName
output projectEndpoint string = projectEndpoint
