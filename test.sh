#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

docker build -t godaddy-wordpress/mwcs-deploy .

if [[ -f .env ]]
then
    source .env
fi

# Create an integration in the UI or if you have cli access:
# ./bin/pagely-mgmt -e mwcs apps:ls 222
# ./bin/pagely-mgmt -e mwcs apps:integration:create 222 20707 default


docker run --rm \
    -e MWCS_DEPLOY_DEST=$MWCS_DEPLOY_DEST \
    -e MWCS_INTEGRATION_SECRET=$MWCS_INTEGRATION_SECRET \
    -e MWCS_INTEGRATION_ID=$MWCS_INTEGRATION_ID \
    -e INPUT_MWCS_APP_ID=$MWCS_APP_ID \
    -e LOG_LEVEL=debug \
    -v "$(pwd)/test":/test \
    -w /test \
    godaddy-wordpress/mwcs-deploy
