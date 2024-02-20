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

setup_colors() {
  if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
    NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m'
  else
    NOFORMAT='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW=''
  fi
}

msg() {
  echo >&2 -e "${1-}"
}

setup_colors

# Check AZ CLI status
msg "${GREEN}(1/4) Checking Azure CLI status...${NOFORMAT}"
{
  az > /dev/null
} || {
  msg "${RED}Azure CLI is not installed."
  msg "${GREEN}Go to https://aka.ms/nubesgen-install-az-cli to install Azure CLI."
  exit 1;
}
{
  az account show > /dev/null
} || {
  msg "${RED}You are not authenticated with Azure CLI."
  msg "${GREEN}Run \"az login\" to authenticate."
  exit 1;
}

msg "${YELLOW}Azure CLI is installed and configured!"

# Check GitHub CLI status
msg "${GREEN}(2/4) Checking GitHub CLI status...${NOFORMAT}"
USE_GITHUB_CLI=false
{
  gh auth status && USE_GITHUB_CLI=true && msg "${YELLOW}GitHub CLI is installed and configured!"
} || {
  msg "${YELLOW}Cannot use the GitHub CLI. ${GREEN}No worries! ${YELLOW}We'll set up the GitHub secrets manually."
  USE_GITHUB_CLI=false
}

# check cli
# create sp
# create github secret


# Create service principal with Contributor role in the subscription
msg "${GREEN}(3/4) Create service principal ${SERVICE_PRINCIPAL_NAME}"
SUBSCRIPTION_ID=$(az account show --query id --output tsv --only-show-errors)
w0=-w0
if [[ $OSTYPE == 'darwin'* ]]; then
  w0=
fi
SERVICE_PRINCIPAL=$(az ad sp create-for-rbac --name ${SERVICE_PRINCIPAL_NAME} --role="Contributor" --scopes="/subscriptions/${SUBSCRIPTION_ID}" --sdk-auth --only-show-errors | base64 $w0)
msg "${YELLOW}\"DISAMBIG_PREFIX\""
msg "${GREEN}${DISAMBIG_PREFIX}"

SP_ID=$(az ad sp list --display-name $SERVICE_PRINCIPAL_NAME --query [0].id -o tsv)
az role assignment create --assignee ${SP_ID} --role "User Access Administrator"

# Create GitHub action secrets
AZURE_CREDENTIALS=$(echo $SERVICE_PRINCIPAL | base64 -d)

msg "${GREEN}(4/4) Create secrets in GitHub"
if $USE_GITHUB_CLI; then
  {
    msg "${GREEN}Using the GitHub CLI to set secrets.${NOFORMAT}"
    gh ${GH_FLAGS} secret set AZURE_CREDENTIALS -b"${AZURE_CREDENTIALS}"
    msg "${YELLOW}\"AZURE_CREDENTIALS\""
    msg "${GREEN}${AZURE_CREDENTIALS}"
    gh ${GH_FLAGS} secret set USER_NAME -b"${USER_NAME}"
    gh ${GH_FLAGS} secret set CLIENT_ID -b"${CLIENT_ID}"
    gh ${GH_FLAGS} secret set SECRET_VALUE -b"${SECRET_VALUE}"
    gh ${GH_FLAGS} secret set TENANT_ID -b"${TENANT_ID}"
    gh ${GH_FLAGS} secret set MSTEAMS_WEBHOOK -b"${MSTEAMS_WEBHOOK}"
    msg "${GREEN}Secrets configured"
  } || {
    USE_GITHUB_CLI=false
  }
fi
if [ $USE_GITHUB_CLI == false ]; then
  msg "${NOFORMAT}======================MANUAL SETUP======================================"
  msg "${GREEN}Using your Web browser to set up secrets..."
  msg "${NOFORMAT}Go to the GitHub repository you want to configure."
  msg "${NOFORMAT}In the \"settings\", go to the \"secrets\" tab and the following secrets:"
  msg "(in ${YELLOW}yellow the secret name and${NOFORMAT} in ${GREEN}green the secret value)"
  msg "${YELLOW}\"AZURE_CREDENTIALS\""
  msg "${GREEN}${AZURE_CREDENTIALS}"
  msg "${YELLOW}\"USER_NAME\""
  msg "${GREEN}${USER_NAME}"
  msg "${YELLOW}\"CLIENT_ID\""
  msg "${GREEN}${CLIENT_ID}"
  msg "${YELLOW}\"SECRET_VALUE\""
  msg "${GREEN}${SECRET_VALUE}"
  msg "${YELLOW}\"TENANT_ID\""
  msg "${GREEN}${TENANT_ID}"
  msg "${YELLOW}\"MSTEAMS_WEBHOOK\""
  msg "${GREEN}${MSTEAMS_WEBHOOK}"
  msg "${NOFORMAT}========================================================================"
fi
