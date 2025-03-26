#!/bin/bash
set -e

# Log the starting of the script
echo "Starting Azure Arc connection script"

# Source configuration if available
if [ -f $ARC_CONFIG_ENV_PATH ]; then
  source $ARC_CONFIG_ENV_PATH
fi

# Validate required environment variables
if [[ -z "$RESOURCE_GROUP" || -z "$LOCATION" || -z "$SUBSCRIPTION_ID" || -z "$TENANT_ID" || -z "$TOKEN" ]]; then
  echo "Error: Required environment variables are not set."
  echo "Required variables: RESOURCE_GROUP, LOCATION, SUBSCRIPTION_ID, TENANT_ID, TOKEN"
  exit 1
fi

# Download the installation package
LINUX_INSTALL_SCRIPT="/tmp/install_linux_azcmagent.sh"
if [ -f "$LINUX_INSTALL_SCRIPT" ]; then 
  rm -f "$LINUX_INSTALL_SCRIPT"; 
fi
output=$(wget https://gbl.his.arc.azure.com/azcmagent-linux -O "$LINUX_INSTALL_SCRIPT" 2>&1)
echo "$output"

# Install the hybrid agent
bash "$LINUX_INSTALL_SCRIPT";

# Connect the machine to Azure Arc
echo "Connecting to Azure Arc using default credentials..."
if azcmagent connect \
    --resource-group "$RESOURCE_GROUP" \
    --tenant-id "$TENANT_ID" \
    --location "$LOCATION" \
    --subscription-id "$SUBSCRIPTION_ID" \
    --access-token "$TOKEN" \
    --cloud "AzureCloud" \
    --tags 'ArcSQLServerExtensionDeployment=Disabled' ; then
  echo "Machine connected to Azure Arc successfully."
else
  echo "Failed to connect the machine to Azure Arc."
  exit 1
fi

echo "Azure Arc connection process completed at: $(date -u  '+%Y-%m-%d %H:%M:%S %Z')"
