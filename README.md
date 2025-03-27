# Scale with Azure Arc

**The contents of this project is for POC purposes only.**

This project provides infrastructure as code (IaC) and scripts to deploy and manage Azure Arc-enabled machines with automated K3s installation.

Arc extends Azure capabilities to manage hybrid and multi-cloud environments. One of those capabilities is governance with [Azure Policies](https://learn.microsoft.com/en-us/azure/governance/policy/), which allow you to manage resources and enforce compliance across your Azure environment. 

## Prerequisites

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) installed and configured
- [Bicep CLI](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/install) installed
- Azure subscription with appropriate permissions

## Deployment Instructions

### Cloud: Deploy the Policy Definition and Assignment

Let's create a policy that deploys a Custom Script that installs a K3s cluster onto any Arc connected machine.

```bash
LOCATION=<location>
ARC_RESOURCE_GROUP=<arc-resource-group-name>

# Note: Policy definition is created at subscription level
policyDefinitionId=$(az deployment sub create --location $LOCATION --template-file cloud/policy-definition.bicep --query 'properties.outputs.policyDefinitionId.value' -o tsv)

az group create -n $ARC_RESOURCE_GROUP -l $LOCATION
az deployment group create -g $ARC_RESOURCEGROUP --template-file cloud/policy-assignment.bicep --parameters policyDefinitionId=$policyDefinitionId
```

### Edge: Deploy the Arc Connected Machine

Now, let's validate this works by creating a new Arc connected machine. Since, Azure VMs are already connected to Azure, this next step performs the steps necessary to prep the VM for Arc before proceeding to onboard the machine.

Once connected, the policy kicks in and creates the extension which installs K3s on the Arc connected machine.

For your convenience, I've provided some approximate completion times for various steps:

- VM creation to k3s install: 5 minutes
- Arc connecttion to k3s install: 2 minutes

```bash
az login
az account set --subscription <SUBSCRIPTION_ID>
ARC_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
ARC_TENANT_ID=$(az account show --query tenantId -o tsv)

az group create -n fake-edge -l $LOCATION
fake-edge/create-new-vm.sh --resource-group fake-edge --arc-resource-group $ARC_RESOURCE_GROUP
```

## Troubleshooting

- cloud-init paths of interest: `/var/log/cloud-init*.log` and `/var/lib/cloud/instances/*`

## Clean Up Resources

To clean up resources when you're done:

```bash
# Remove the Arc machine
az connectedmachine delete --name <MACHINE_NAME> --resource-group <RESOURCE_GROUP>

# Remove the policy assignment
az policy assignment delete --name <POLICY_ASSIGNMENT_NAME>

# Remove the resource group
az group delete --name <RESOURCE_GROUP>
```
