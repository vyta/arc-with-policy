#!/bin/bash

usage() {
  echo "Usage: $0 [--new-sp|--existing-sp] --resource-group <resource-group-name> [--arc-resource-group <arc-resource-group-name>]"
  echo "  --new-sp                Create a new service principal (default)"
  echo "  --existing-sp           Use existing service principal"
  echo "  --arc-resource-group    Azure Arc resource group name"
  echo
  echo "Environment Variables:"
  echo "  Required (if using existing service principal):"
  echo "    APP_ID"
  echo
  exit 1
}

CREATE_NEW_SP=true
ARC_RESOURCE_GROUP=""

# Parse command-line options
while [[ $# -gt 0 ]]; do
  case "$1" in
    --existing-sp)
      CREATE_NEW_SP=false
      shift
      ;;
    --new-sp)
      CREATE_NEW_SP=true
      shift
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

# Check if Arc resource group parameter is provided when creating a new SP
if [ "$CREATE_NEW_SP" = true ] && [ -z "$ARC_RESOURCE_GROUP" ]; then
  echo "Error: Arc resource group parameter is required when creating a new service principal"
  usage
fi

if [ "$CREATE_NEW_SP" = true ]; then
  echo "Creating new service principal..."
  # Generate a valid display name
  displayName=arc-$(date +%Y%m%d%H%M%S)
  appId=$(az ad app create --display-name $displayName --query appId -o tsv)
  spId=$(az ad sp create --id $appId --query id -o tsv)
  az role assignment create --assignee $spId --role "Azure Connected Machine Onboarding" --scope /subscriptions/$(az account show --query id -o tsv)/resourceGroups/$ARC_RESOURCE_GROUP

  echo "New service principal created and role assigned."
else
  echo "Using existing service principal..."
  if [ -z "$APP_ID" ]; then
    echo "Error: APP_ID environment variable is not set for existing service principal"
    exit 1
  fi
  appId=$APP_ID
fi

endDate=$(date -d "+10 days" +"%Y-%m-%d")
az ad app credential reset --id $appId --end-date $endDate --query password -o tsv
