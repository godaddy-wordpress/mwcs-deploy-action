#!/usr/bin/env bash
#
# Deploy to MWCS app https://www.godaddy.com/hosting/ecommerce-hosting
# Required globals:
#     MWCS_DEPLOY_DEST
#     MWCS_INTEGRATION_SECRET
#     MWCS_INTEGRATION_ID
#     MWCS_APP_ID
#
# Optional globals:
#     MWCS_WORKING_DIR (default: "$PWD")
#     MWCS_API_URL (default: "https://mgmt.mwcs.godaddy.com/api/")

set -o errexit
set -o pipefail
set -o nounset

MWCS_DEPLOY_DEST=${INPUT_MWCS_DEPLOY_DEST:-${MWCS_DEPLOY_DEST:-}}
MWCS_INTEGRATION_SECRET=${INPUT_MWCS_INTEGRATION_SECRET:-${MWCS_INTEGRATION_SECRET:-}}
MWCS_INTEGRATION_ID=${INPUT_MWCS_INTEGRATION_ID:-${MWCS_INTEGRATION_ID:-}}
MWCS_APP_ID=${INPUT_MWCS_APP_ID:-${MWCS_APP_ID:-}}
MWCS_WORKING_DIR=${INPUT_MWCS_WORKING_DIR:-${MWCS_WORKING_DIR:-"$(pwd)"}}
MWCS_API_URL=${INPUT_MWCS_API_URL:-${MWCS_API_URL:-"https://mgmt.mwcs.godaddy.com/api"}}
LOG_LEVEL=${LOG_LEVEL:-"info"}

if [[ -z "$MWCS_DEPLOY_DEST" ]]; then
    echo "MWCS_DEPLOY_DEST is required"
    exit 1
fi
if [[ -z "$MWCS_INTEGRATION_SECRET" ]]; then
    echo "MWCS_INTEGRATION_SECRET is required"
    exit 1
fi
if [[ -z "$MWCS_APP_ID" ]]; then
    echo "MWCS_APP_ID is required"
    exit 1
fi
if [[ -z "$MWCS_WORKING_DIR" ]]; then
    echo "MWCS_WORKING_DIR is required"
    exit 1
fi


echo "Running deploy with the following settings: "
echo "MWCS_DEPLOY_DEST: $MWCS_DEPLOY_DEST"
echo "MWCS_INTEGRATION_ID: $MWCS_INTEGRATION_ID"
echo "MWCS_APP_ID: $MWCS_APP_ID"
echo "MWCS_WORKING_DIR: $MWCS_WORKING_DIR"


outputGroupStart ()
{
    echo "::group::$1"
}

outputGroupEnd ()
{
    echo "::endgroup::"
}

# gz everything in the `pagelydeploy` dir as that's what we're deploying
outputGroupStart 'Tarball from the contents of the working dir'
tar --exclude-vcs -zcvf "/tmp/deploy.tar.gz" -C "$MWCS_WORKING_DIR" .
ls -lh /tmp/deploy.tar.gz
outputGroupEnd

URL_LOOKUP_OUTPUT=$(mktemp)
URL_LOOKUP_URL="${MWCS_API_URL}/apps/integration/${MWCS_INTEGRATION_ID}/endpoint?appId=${MWCS_APP_ID}"

echo "Lookup app's deploy URL"
if [[ $LOG_LEVEL == 'debug' ]]; then
    echo $URL_LOOKUP_URL
fi
if http --check-status --ignore-stdin --timeout=10 GET "$URL_LOOKUP_URL" \
    "X-Token: $MWCS_INTEGRATION_SECRET" \
    > $URL_LOOKUP_OUTPUT
then
    DEPLOY_URL="$(cat $URL_LOOKUP_OUTPUT)&tail=1"
    echo "Successfully got deploy URL"
else
    code=$?

    echo "FAILURE in request to $URL_LOOKUP_URL"
    case $code in
        2) echo 'Request timed out!' ;;
        3) echo 'Unexpected HTTP 3xx Redirection!' ;;
        4) echo 'HTTP 4xx Client Error!';;
        5) echo 'HTTP 5xx Server Error!' ;;
        6) echo 'Exceeded --max-redirects=<n> redirects!' ;;
        *) echo 'Other Error!' ;;
    esac
    cat $URL_LOOKUP_OUTPUT
    exit 1
fi

echo "Deploying"
if [[ $LOG_LEVEL == 'debug' ]]; then
    echo $DEPLOY_URL
fi
DEPLOY_OUTPUT=$(mktemp)
DEPLOY_HTTP_CODE_FILE=$(mktemp)

# Switch to curl for streaming here as httpie seems to have issues actually streaming this data back even though it has line breaks
set -o pipefail
set +o errexit
curl \
  --fail-with-body \
  --show-error \
  --silent \
  --no-buffer \
  --header "X-Token: ${MWCS_INTEGRATION_SECRET}" \
  --write-out "%{stderr}%{http_code}" \
  --request POST \
  --form "dest=${MWCS_DEPLOY_DEST}" \
  --form 'file=@/tmp/deploy.tar.gz' \
  "${DEPLOY_URL}" 2>${DEPLOY_HTTP_CODE_FILE} | tee $DEPLOY_OUTPUT
DEPLOY_CURL_EXIT_CODE=$?
DEPLOY_HTTP_RESP_CODE="$(cat $DEPLOY_HTTP_CODE_FILE)"

if [[ $DEPLOY_CURL_EXIT_CODE -ne 0 ]]; then
    echo "FAILURE in deploy request to: ${DEPLOY_URL}"
    if [[ ! -z "${DEPLOY_HTTP_RESP_CODE}" ]]; then
        echo "HTTP response code was: ${DEPLOY_HTTP_RESP_CODE}"
    fi
    exit 1
fi
if [[ "$(tail -n 1 "$DEPLOY_OUTPUT")" == "FAILURE" ]]; then
    exit 1
fi
