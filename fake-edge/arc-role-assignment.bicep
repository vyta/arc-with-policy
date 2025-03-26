targetScope = 'resourceGroup'

@description('Principal ID for the Virtual Machine')
param principalId string

// Azure Connected Machine Onboarding Role
// ref: https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
var arcOnboardingRoleID = 'b64e21ea-ac4e-4cdf-9dc9-5b892992bee7'

resource arcOnboardingRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(subscription().tenantId, principalId, 'ArcOnboardingRoleAssignment')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', arcOnboardingRoleID)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}
