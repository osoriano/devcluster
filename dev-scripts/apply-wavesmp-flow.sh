#!/bin/bash
#
# Apply the wavesmp push flow
# This can be useful when enabling or disabling the flow
#
set -o errexit
set -o nounset
set -o pipefail


cd "$(dirname "$0")"
cd ..


FLOW_NAMESPACE=wavesmp
FLOW_PATH=./flows/wavesmp/github-push.yaml


kubectl \
  apply \
  --server-side \
  -n "${FLOW_NAMESPACE}" \
  -f "${FLOW_PATH}"
