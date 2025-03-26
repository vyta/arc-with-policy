#!/bin/bash
set -e

# Script to prepare a VM for Azure Arc installation
# This script installs the prerequisites and configures the system for Arc agent

echo "Starting VM preparation for Azure Arc..."

# Update system packages
echo "Updating system packages..."
apt-get update -y
apt-get upgrade -y

# Install required packages
echo "Installing required packages..."
apt-get install -y \
    ca-certificates \
    curl \
    apt-transport-https \
    lsb-release \
    gnupg \
    python3-pip \
    jq

echo "Setting environment variable to override Azure Arc..."
export MSFT_ARC_TEST=true
systemctl set-environment MSFT_ARC_TEST=true

echo "Disabling Azure VM Guest Agent..."
systemctl stop walinuxagent
systemctl disable walinuxagent

echo "Blocking access to IMDS endpoint for Ubuntu..."
ufw --force enable
ufw deny out from any to 169.254.169.254
ufw deny out from any to 169.254.169.253
ufw default allow incoming
# For SUSE use firewall-cmd 

# Create a flag file to indicate preparation is complete
mkdir -p /etc/azure-arc-prep
touch /etc/azure-arc-prep/prep-complete

echo "VM preparation for Azure Arc completed successfully!"
echo "The system is now ready for Azure Arc agent installation."
echo "The preparation files are located in /etc/azure-arc-prep."
echo "Run the 'arc-connect-machine.sh' script to connect this machine to Azure Arc."
