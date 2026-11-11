#!/bin/bash
#
# In case the jettison-controller is in a disabled state, the devcluster startup script
# may not complete.
#
# This syncs the jettison-controller manually to get past the issue
#
set -o errexit
set -o nounset
set -o pipefail


CURL_HOST_NAMESPACE=osoriano
CURL_HOST_RESOURCE=deploy/osoriano

ARGOCD_APP_NAMESPACE=jettisonproj
ARGOCD_APP_NAME=jettison-prod-controller

kubectl \
  --namespace "${CURL_HOST_NAMESPACE}" \
  exec \
  -it \
  "${CURL_HOST_RESOURCE}" \
  -- \
  curl \
  --silent \
  --show-error \
  --fail \
  --request POST \
  "http://jettison-api-service.jettisonproj:2846/api/v1/namespaces/${ARGOCD_APP_NAMESPACE}/applications/${ARGOCD_APP_NAME}/sync"
