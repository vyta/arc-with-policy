targetScope = 'resourceGroup'

// Parameters
@description('Name for the policy assignment')
param policyAssignmentName string = 'k3s-cluster-policy'

@description('Name for the policy assignment')
param policyDefinitionId string

// Policy assignment
resource policyAssignment 'Microsoft.Authorization/policyAssignments@2025-01-01' = {
  name: policyAssignmentName
  location: resourceGroup().location
  properties: {
    policyDefinitionId: policyDefinitionId
    displayName: 'Ensure Arc-enabled machines in resource group run k3s clusters'
    description: 'This policy ensures that all Arc-enabled machines in the resource group run k3s clusters'
    enforcementMode: 'Default'
  }
  identity: {
    type: 'SystemAssigned'
  }
}
// Contributor Role
// ref: https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
var contributorRoleId = 'b24988ac-6180-42a0-ab88-20f7382dd24c'

resource policyContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(resourceGroup().id, policyAssignmentName)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', contributorRoleId)
    principalId: policyAssignment.identity.principalId
    principalType: 'ServicePrincipal'
  }
}
