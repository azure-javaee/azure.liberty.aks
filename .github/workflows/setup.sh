#!/bin/bash

# Read the JSON file and iterate over all key-value pairs
jq -r 'to_entries[] | .key + "=" + (.value.value // "")' config.json | while IFS="=" read -r key value
do
  if [ -z "$value" ]; then
    hint=$(jq -r --arg KEY "$key" '.[$KEY].hint' config.json)
    echo "$hint"
    read value < /dev/tty
  fi
  # Use the declare command to dynamically create variables and export them
  declare -x "$key=$value"
done

msg_green() {
  echo >&2 -e "\033[32m$1\033[0m"
}
msg_red() {
  echo >&2 -e "\033[31m$1\033[0m"
}
msg_yellow() {
  echo -e "\033[33m$1\033[0m"
}

# Check AZ CLI status
msg_green "(1/4) Checking Azure CLI status..."
{
  az > /dev/null
} || {
  msg_red "Azure CLI is not installed."
  msg_green "Go to https://aka.ms/nubesgen-install-az-cli to install Azure CLI."
  exit 1;
}
{
  az account show > /dev/null
} || {
  msg_red "You are not authenticated with Azure CLI."
  msg_green "Run \"az login\" to authenticate."
  exit 1;
}

msg_yellow "Azure CLI is installed and configured!"

# Check GitHub CLI status
msg_green "(2/4) Checking GitHub CLI status..."
USE_GITHUB_CLI=false
{
  gh auth status && USE_GITHUB_CLI=true && msg "${YELLOW}GitHub CLI is installed and configured!"
} || {
  msg_yellow "Cannot use the GitHub CLI. No worries! We'll set up the GitHub secrets manually."
  USE_GITHUB_CLI=false
}

# Check CLI(Both Azure and GitHub) status
# Create Service Principal
# Create github secrets


# Create service principal with Contributor role in the subscription
msg_green "(3/4) Create service principal ${SERVICE_PRINCIPAL_NAME}"
SUBSCRIPTION_ID=$(az account show --query id --output tsv --only-show-errors)
w0=-w0
if [[ $OSTYPE == 'darwin'* ]]; then
  w0=
fi
SERVICE_PRINCIPAL=$(az ad sp create-for-rbac --name ${SERVICE_PRINCIPAL_NAME} --role="Contributor" --scopes="/subscriptions/${SUBSCRIPTION_ID}" --sdk-auth --only-show-errors | base64 $w0)
msg_yellow "DISAMBIG_PREFIX\""
msg_green "${DISAMBIG_PREFIX}"

SP_ID=$(az ad sp list --display-name $SERVICE_PRINCIPAL_NAME --query [0].id -o tsv)
az role assignment create --assignee ${SP_ID} --role "User Access Administrator"

# Create GitHub action secrets
AZURE_CREDENTIALS=$(echo $SERVICE_PRINCIPAL | base64 -d)

msg_green "(4/4) Create secrets in GitHub"
if $USE_GITHUB_CLI; then
  {
    msg_green "Using the GitHub CLI to set secrets."
    gh ${GH_FLAGS} secret set AZURE_CREDENTIALS -b"${AZURE_CREDENTIALS}"
    msg "${YELLOW}\"AZURE_CREDENTIALS\""
    msg_green "${AZURE_CREDENTIALS}"
    gh ${GH_FLAGS} secret set USER_NAME -b"${USER_NAME}"
    gh ${GH_FLAGS} secret set CLIENT_ID -b"${CLIENT_ID}"
    gh ${GH_FLAGS} secret set SECRET_VALUE -b"${SECRET_VALUE}"
    gh ${GH_FLAGS} secret set TENANT_ID -b"${TENANT_ID}"
    gh ${GH_FLAGS} secret set MSTEAMS_WEBHOOK -b"${MSTEAMS_WEBHOOK}"
    msg_green "Secrets configured"
  } || {
    USE_GITHUB_CLI=false
  }
fi
if [ $USE_GITHUB_CLI == false ]; then
  msgmsg_green "======================MANUAL SETUP======================================"
  msg_green "Using your Web browser to set up secrets..."
  msg_yellow "Go to the GitHub repository you want to configure."
  msg_yellow "In the \"settings\", go to the \"secrets\" tab and the following secrets:"
  msg_yellow "the secret name and in green the secret value)"
  msg_yellow "\"AZURE_CREDENTIALS\":"
  msg_green "${AZURE_CREDENTIALS}"

  jq -r 'to_entries[] | .key + "=" + (.value.type // "")' config.json | while IFS="=" read -r key type
  do
    msg_yellow "\"$key\":"
    msg_green "${ ${key} }"
  done
fi
