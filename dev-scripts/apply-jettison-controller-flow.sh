#!/bin/bash
#
# Apply the jettison-controller push flow
# This can be useful when enabling or disabling the flow
#
set -o errexit
set -o nounset
set -o pipefail


cd "$(dirname "$0")"
cd ..


FLOW_NAMESPACE=jettisonproj
FLOW_PATH=./flows/jettisonproj/jettison-controller-github-push.yaml


kubectl \
  apply \
  --server-side \
  -n "${FLOW_NAMESPACE}" \
  -f "${FLOW_PATH}"
