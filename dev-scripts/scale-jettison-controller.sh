#!/bin/bash
#
# Scale the jettison-prod-controller rollout
#
set -o errexit
set -o nounset
set -o pipefail


ROLLOUT_NAMESPACE=jettisonproj
ROLLOUT_NAME=jettison-controller-manager
NUM_REPLICAS=1

kubectl \
  --namespace "${ROLLOUT_NAMESPACE}" \
  scale \
  "rollouts/${ROLLOUT_NAME}" \
  --replicas "${NUM_REPLICAS}"
