#!/bin/bash

usage() {
  echo "Usage: $0  --resource-group <resource-group-name> --arc-resource-group <arc-resource-group-name>"
  echo "  --resource-group        Azure resource group name (required)"
  echo "  --arc-resource-group    Azure Arc resource group name (required)"
  echo
  echo "Environment variables:"
  echo "  ARC_SUBSCRIPTION_ID     (Optional) Defaults to current subscription via `az account show`"
  echo "  ARC_TENANT_ID           (Optional) Defaults to current tenant via `az account show`"
  echo
  exit 1
}

RESOURCE_GROUP=""

# Parse command-line options
while [[ $# -gt 0 ]]; do
  case "$1" in
    --resource-group)
      RESOURCE_GROUP="$2"
      shift 2
      ;;
    --arc-resource-group)
      ARC_RESOURCE_GROUP="$2"
      shift 2
      ;;
    *)
      usage
      ;;
  esac
done

# Check if resource group parameter is provided
if [ -z "$RESOURCE_GROUP" ] || [ -z "$ARC_RESOURCE_GROUP" ]; then
  echo "Error: --resource-group and --arc-resource-group parameters are required"
  usage
fi

# Use environment variables if set, otherwise use default values
ARC_SUBSCRIPTION_ID=${ARC_SUBSCRIPTION_ID:-$(az account show --query id -o tsv)}
ARC_TENANT_ID=${ARC_TENANT_ID:-$(az account show --query tenantId -o tsv)}

# Display the values being used
echo "Using ARC_SUBSCRIPTION_ID: $ARC_SUBSCRIPTION_ID"
echo "Using ARC_TENANT_ID: $ARC_TENANT_ID"

# Generate or use existing SSH key
SSH_KEY_PATH="$HOME/.ssh/id_rsa"
if [ ! -f "$SSH_KEY_PATH" ]; then
  echo "SSH key not found. Generating new SSH key pair..."
  ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -q -N ""
  echo "SSH key pair generated at $SSH_KEY_PATH"
fi

# Read the public SSH key
SSH_PUBLIC_KEY=$(cat "${SSH_KEY_PATH}.pub")

vmName=vm-$(date +%Y%m%d%H%M%S)
bicepPath=$(dirname "$0")/arc-test-vm.bicep

echo "Running $vmName deployment..."
sshCommand=$(az deployment group create --resource-group $RESOURCE_GROUP --template-file "$bicepPath" \
  --parameters vmName=$vmName \
    adminSshPublicKey="$SSH_PUBLIC_KEY" \
    arcOnboardingConfig='{"resourceGroup":"'"$ARC_RESOURCE_GROUP"'","subscriptionId":"'"$ARC_SUBSCRIPTION_ID"'","tenantId":"'"$ARC_TENANT_ID"'"}'  \
    --query properties.outputs.sshCommand.value -o tsv)


if [ -z "$sshCommand" ]; then
  echo "Error: Failed to retrieve SSH command."
  exit 1
fi

echo "Created at: $(date -u  '+%Y-%m-%d %H:%M:%S %Z')"
echo "SSH Command: $sshCommand"
