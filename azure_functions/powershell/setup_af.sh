#!/bin/bash

# Parameters
AZURE_SP_APP_ID=$1
AZURE_SP_PASSWORD=$2
AZURE_SP_TENANT=$3
RESOURCE_GROUP=$4
LOCATION=japaneast
NAME=$5
STORAGE_NAME=${NAME}storage
MODULE_URL=$6


# Install Azure Functions Core Tools
apt-get update -y
apt-get install -y sudo unzip
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
sudo mv microsoft.gpg /etc/apt/trusted.gpg.d/microsoft.gpg
sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/debian/$(lsb_release -rs | cut -d'.' -f 1)/prod $(lsb_release -cs) main" > /etc/apt/sources.list.d/dotnetdev.list'
apt-get update -y
apt-get install azure-functions-core-tools-3

# Login Azure 
az login --service-principal --username $AZURE_SP_APP_ID --password $AZURE_SP_PASSWORD --tenant $AZURE_SP_TENANT

# Create Azure Functions
IS_RG_EXISTED=`az group exists -g $RESOURCE_GROUP`
if "$IS_RG_EXISTED"; then
	echo "$RESOURCE_GROUP is already existed."
else
	az group create --name $RESOURCE_GROUP --location $LOCATION
fi

NAME_AVAILABLE=`az storage account check-name --name $STORAGE_NAME --query nameAvailable`
if "$NAME_AVAILABLE"; then
	az storage account create --name $STORAGE_NAME --location $LOCATION --resource-group $RESOURCE_GROUP --sku Standard_LRS
else
	echo "$STORAGE_NAME is already existed."
fi

ARRAY=`az functionapp list -g $RESOURCE_GROUP --query "[?name=='$NAME'].name | sort(@) | {names: join(',',@)} | names" --output tsv`
echo $ARRAY
if [ -z "$ARRAY" ]; then
    az functionapp create --resource-group $RESOURCE_GROUP --consumption-plan-location $LOCATION --runtime python --runtime-version 3.8 --functions-version 3 --name $NAME --storage-account $STORAGE_NAME --os-type linux
fi

# Deploy Source code to Azure Functions
wget -O module.zip $MODULE_URL
mkdir project
unzip module.zip -d project
cd project
az functionapp list -g $RESOURCE_GROUP
sleep 60
func azure functionapp publish $NAME

# Logout Azure 
az logout

