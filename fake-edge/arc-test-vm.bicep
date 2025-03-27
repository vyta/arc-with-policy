@description('Username for the Virtual Machine')
param adminUsername string = 'arctestadmin'

@description('SSH public key for the Virtual Machine')
param adminSshPublicKey string

@description('Name for the Virtual Machine')
param vmName string = '${resourceGroup().name}-vm'

@description('VM Size')
param vmSize string = 'Standard_D2s_v3'

@description('Location for all resources')
param location string = resourceGroup().location

@description('Virtual Network Name')
param vnetName string = '${resourceGroup().name}-vnet'

@description('Address Prefix')
param addressPrefix string = '10.0.0.0/16'

@description('Subnet Name')
param subnetName string = '${resourceGroup().name}-subnet'

@description('Subnet Prefix')
param subnetPrefix string = '10.0.0.0/24'

@description('Network Security Group Name')
param nsgName string = '${resourceGroup().name}-nsg'

@description('Configuration for Azure Arc onboarding')
param arcOnboardingConfig object = {
  resourceGroup: ''
  subscriptionId: subscription().subscriptionId
  tenantId: subscription().tenantId
}

// Create NSG with SSH rule
resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'SSH'
        properties: {
          priority: 1000
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
    ]
  }
}

// Create Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

// Create Public IP
resource publicIP 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: '${vmName}-pip'
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    dnsSettings: {
      domainNameLabel: toLower('${vmName}-${uniqueString(resourceGroup().id)}')
    }
  }
}

// Create Network Interface
resource nic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: '${vmName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIP.id
          }
          subnet: {
            id: vnet.properties.subnets[0].id
          }
        }
      }
    ]
  }
}

// Read the actual content of the scripts
var prepareVmScript = loadTextContent('./data/prep-vm-for-arc.sh')
var arcConnectScript = loadTextContent('./data/connect-machine-via-arc.sh')

// Process the script content to properly escape it for cloud-init
var processedPrepareScript = replace(prepareVmScript, '\n', '\n      ')
var processedArcConnectScript = replace(arcConnectScript, '\n', '\n      ')

// Create cloud-init configuration with direct variable embedding
// Disable interpolation perference since interpolation is not supported for multi-line strings 
#disable-next-line prefer-interpolation
var cloudInit = concat('''
#cloud-config
package_update: true
package_upgrade: true
apt:
  sources:
    az.list:
      source: deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli bionic main
      keyid: BC528686B50D79E339D3721CEB3E94ADBE1229CF

packages:
  - ca-certificates
  - curl
  - apt-transport-https
  - lsb-release
  - gnupg
  - python3-pip
  - jq
  - ufw
  - wget
  - azure-cli

write_files:
  - path: /home/''','${adminUsername}','''/prepare-vm.sh
    content: |
      ''','${processedPrepareScript}\n','''
    owner: root:root
    permissions: '0744'
  - path: /home/''','${adminUsername}','''/arc-connect-machine.sh
    content: |
      ''','${processedArcConnectScript}\n','''
    owner: ''','${adminUsername}:${adminUsername}\n','''
    permissions: '0755'
    defer: true
  - path: /home/''','${adminUsername}','''/arc-config.env
    content: |
      export RESOURCE_GROUP=''','${arcOnboardingConfig.resourceGroup}\n','''
      export LOCATION=''','${location}\n','''
      export MACHINE_NAME=''','${vmName}\n','''
      export SUBSCRIPTION_ID=''','${arcOnboardingConfig.subscriptionId}\n','''
      export TENANT_ID=''','${arcOnboardingConfig.tenantId}\n','''
    owner: ''','${adminUsername}:${adminUsername}\n','''
    permissions: '0644'
    defer: true

runcmd:
  - touch /home/''','${adminUsername}','''/runcmdStatus.running
  - export TOKEN=$(curl -s -H Metadata:true "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fmanagement.azure.com/" | jq -r .access_token)
  - bash /home/''','${adminUsername}','''/prepare-vm.sh
  - export ARC_CONFIG_ENV_PATH=/home/''','${adminUsername}','''/arc-config.env
  - bash /home/''','${adminUsername}','''/arc-connect-machine.sh
  - rm /home/''','${adminUsername}','''/runcmdStatus.running && touch /home/''','${adminUsername}','''/runcmdStatus.complete
''')

// Create VM with cloud-init
resource vm 'Microsoft.Compute/virtualMachines@2024-11-01' = {
  name: vmName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: adminSshPublicKey
            }
          ]
        }
        provisionVMAgent: true
      }
      customData: base64(cloudInit)
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'UbuntuServer'
        sku: '18.04-LTS'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}


module arcRoleAssignment './arc-role-assignment.bicep' = {
  name: 'arcRoleAssignment'
  params: {
    principalId: vm.identity.principalId
  }
  scope: resourceGroup(arcOnboardingConfig.resourceGroup)
}

// Outputs
output sshCommand string = 'ssh ${adminUsername}@${publicIP.properties.dnsSettings.fqdn}'
