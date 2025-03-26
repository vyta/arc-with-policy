// Set the target scope to subscription for resource group deployment
targetScope = 'subscription'

// Variables
var k3sInstallScript = '''
#!/bin/bash
curl -sfL https://get.k3s.io | sh -
'''

// Custom policy definition for k3s installation
resource policyDefinition 'Microsoft.Authorization/policyDefinitions@2025-01-01' = {
  name: 'install-k3s-on-arc-machines'
  properties: {
    displayName: 'Deploy k3s on Arc-enabled machines'
    description: 'This policy deploys a customscript extension to install K3s on arc machines.'
    policyType: 'Custom'
    mode: 'All'
    metadata: {
      category: 'Azure Arc'
    }
    parameters: {}
    policyRule: {
      if: {
        field: 'type'
        equals: 'Microsoft.HybridCompute/machines'
      }
      then: {
        effect: 'deployIfNotExists'
        details: {
          type: 'Microsoft.HybridCompute/machines/extensions'
          roleDefinitionIds: [
            '/providers/microsoft.authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c' // Contributor role
          ]
          existenceCondition: {
            allOf: [
              {
                field: 'Microsoft.HybridCompute/machines/extensions/publisher'
                equals: 'Microsoft.Azure.Extensions'
              }
              {
                field: 'Microsoft.HybridCompute/machines/extensions/type'
                equals: 'CustomScript'
              }
              {
                field: 'name'
                equals: 'K3sInstallation'
              }
              {
                field: 'Microsoft.HybridCompute/machines/extensions/provisioningState'
                equals: 'Succeeded'
              }
            ]
          }
          evaluationDelay: 'AfterProvisioningSuccess'
          deployment: {
            properties: {
              mode: 'incremental'
              parameters: {
                machineName: {
                  value: '[field(\'name\')]'
                }
                location: {
                  value: '[field(\'location\')]'
                }
              }
              template: {
                '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
                contentVersion: '1.0.0.0'
                parameters: {
                  machineName: {
                    type: 'string'
                  }
                  location: {
                    type: 'string'
                  }
                }
                resources: [
                  {
                    type: 'Microsoft.HybridCompute/machines/extensions'
                    name: '[concat(parameters(\'machineName\'), \'/K3sInstallation\')]'
                    location: '[parameters(\'location\')]'
                    apiVersion: '2024-07-10'
                    properties: {
                      publisher: 'Microsoft.Azure.Extensions'
                      type: 'CustomScript'
                      typeHandlerVersion: '2.1'
                      autoUpgradeMinorVersion: true
                      settings: {
                        script: base64(k3sInstallScript)
                      }
                    }
                  }
                ]
              }
            }
          }
        }
      }
    }
  }
}

// Outputs
output policyDefinitionId string = policyDefinition.id
