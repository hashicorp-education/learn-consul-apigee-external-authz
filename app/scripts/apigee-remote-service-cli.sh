#!/bin/bash

# Exit if any of the intermediate steps fail
set -e

# Check if the APIGEE_ACCESS_TOKEN variable is set
if [ -z "$APIGEE_ACCESS_TOKEN" ]; then
  echo "Error: Apigee access token env (APIGEE_ACCESS_TOKEN) is not set. Please refer to README.md file for details" >&2
  exit 1
fi

OS_NAME=$(uname -s)

if [[ "$OS_NAME" == "Linux" ]]; then
    export APIGEE_REMOTE_OS='linux'
elif [[ "$OS_NAME" == "Darwin" ]]; then
    export APIGEE_REMOTE_OS='macOS'
    if ! [ -x "$(command -v timeout)" ]; then
    echo "Please install the timeout command for macOS. E.g. 'brew install coreutils'" >&2
    exit 2
    fi
else
    echo "💣 Only Linux and macOS are supported at this time. You seem to be running on $OS_NAME." >&2
    exit 2
fi

# Gather inputs from Terraform
eval "$(jq -r '@sh "APIGEE_REMOTE_VERSION=\(.apigee_remote_version) GCP_PROJECT_ID=\(.project_id) APIGEE_ENV=\(.apigee_env_name) APIGEE_RUNTIME=\(.apigee_runtime) APIGEE_NS=\(.apigee_namespace) APIGEE_ANALYTICS_SA=\(.apigee_analytics_sa)"')"

# Main invocation of the apigee-remote-service cli
curl -L https://github.com/apigee/apigee-remote-service-cli/releases/download/v${APIGEE_REMOTE_VERSION}/apigee-remote-service-cli_${APIGEE_REMOTE_VERSION}_${APIGEE_REMOTE_OS}_64-bit.tar.gz > apigee-remote-service-cli.tar.gz
tar -xf apigee-remote-service-cli.tar.gz
rm apigee-remote-service-cli.tar.gz
./apigee-remote-service-cli provision -f \
--organization ${GCP_PROJECT_ID} \
--environment ${APIGEE_ENV} \
--runtime ${APIGEE_RUNTIME} \
--namespace ${APIGEE_NS} \
--token ${APIGEE_ACCESS_TOKEN} \
--analytics-sa ${APIGEE_ANALYTICS_SA}> config.yaml
rm apigee-remote-service-cli
rm LICENSE
rm README.md

apigee_remote_cert=$(grep -o 'remote-service.crt: .*' config.yaml | awk '{ print $2}')
apigee_remote_key=$(grep -o 'remote-service.key: .*' config.yaml | awk '{ print $2}')
apigee_remote_properties=$(grep -o 'remote-service.properties: .*' config.yaml | awk '{ print $2}')
client_secret=$(grep -o 'client_secret.json: .*' config.yaml | awk '{ print $2}')

# Safely produce a JSON object containing the result value.
# jq will ensure that the value is properly quoted
# and escaped to produce a valid JSON string.
jq -n --arg apigee_remote_cert "$apigee_remote_cert" --arg apigee_remote_key "$apigee_remote_key" --arg apigee_remote_properties "$apigee_remote_properties" --arg client_secret "$client_secret" '{"apigee_remote_cert":$apigee_remote_cert,"apigee_remote_key":$apigee_remote_key,"apigee_remote_properties":$apigee_remote_properties,"client_secret":$client_secret}'
