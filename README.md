# POC - Scale with Azure Arc

This project provides infrastructure as code (IaC) and scripts to deploy and manage Azure Arc-enabled machines with automated K3s installation. The contents of this project is for POC purposes only.

## Prerequisites

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) installed and configured
- [Bicep CLI](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/install) installed
- Azure subscription with appropriate permissions

## Deployment Instructions

### Cloud: Deploy the Policy Definition and Assignment

```bash
LOCATION=<location>
# Note: Policy definition is created at subscription level
policyDefinitionId=$(az deployment sub create --location $LOCATION --template-file cloud/policy-definition.bicep --query 'properties.outputs.policyDefinitionId.value' -o tsv)
az deployment group create -g arc-test --template-file cloud/policy-assignment.bicep --parameters policyDefinitionId=$policyDefinitionId
```

### Edge: Deploy the Arc Connected Machine

Approximate duration:
- VM creation to k3s install: 5 minutes
- Arc connecttion to k3s install: 2 minutes

```bash
az login
az account set --subscription <SUBSCRIPTION_ID>
az group create -n fake-edge -l $LOCATION
fake-edge/create-new-vm.sh --resource-group fake-edge
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
