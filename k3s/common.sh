#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail


INSTALL_K3S_EXEC='--flannel-backend=none'
INSTALL_K3S_EXEC+=' --disable-network-policy'
INSTALL_K3S_EXEC+=' --disable-kube-proxy'
INSTALL_K3S_EXEC+=' --disable=traefik'
export INSTALL_K3S_EXEC

# For Cilium chart releases, see:
# https://github.com/cilium/charts
CILIUM_CHART_VERSION=1.20.4

# For the stable Cilium CLI version, see:
# https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt
CILIUM_CLI_VERSION=v0.20.2

# For Gateway CRD releases, see:
# https://github.com/kubernetes-sigs/gateway-api/releases
# https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/
GATEWAY_CRD_VERSION=v1.6.3

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

req() {
  curl \
    --silent \
    --show-error \
    --fail \
    "$@"
}
