#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail


INSTALL_K3S_EXEC='--flannel-backend=none'
INSTALL_K3S_EXEC+=' --disable-network-policy'
INSTALL_K3S_EXEC+=' --disable-kube-proxy'
INSTALL_K3S_EXEC+=' --disable=traefik'
export INSTALL_K3S_EXEC

CILIUM_CHART_VERSION=1.19.1
CILIUM_CLI_VERSION=v0.19.0
GATEWAY_CRD_VERSION=v1.7.0

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# These should be in sync with cilium-values.yaml
API_SERVER_IP=localhost
API_SERVER_PORT=6443

req() {
  curl \
    --silent \
    --show-error \
    --fail \
    "$@"
}
