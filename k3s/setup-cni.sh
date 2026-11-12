#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

cd "$(dirname "$0")"
source common.sh

# For the CRDs to install, see: https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/
echo "Installing gateway api"
kubectl apply --server-side -f "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/${GATEWAY_CRD_VERSION}/config/crd/standard/gateway.networking.k8s.io_gatewayclasses.yaml"
kubectl apply --server-side -f "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/${GATEWAY_CRD_VERSION}/config/crd/standard/gateway.networking.k8s.io_gateways.yaml"
kubectl apply --server-side -f "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/${GATEWAY_CRD_VERSION}/config/crd/standard/gateway.networking.k8s.io_httproutes.yaml"
kubectl apply --server-side -f "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/${GATEWAY_CRD_VERSION}/config/crd/standard/gateway.networking.k8s.io_referencegrants.yaml"
kubectl apply --server-side -f "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/${GATEWAY_CRD_VERSION}/config/crd/standard/gateway.networking.k8s.io_grpcroutes.yaml"
kubectl apply --server-side -f "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/${GATEWAY_CRD_VERSION}/config/crd/standard/gateway.networking.k8s.io_backendtlspolicies.yaml"
kubectl apply --server-side -f "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/${GATEWAY_CRD_VERSION}/config/crd/standard/gateway.networking.k8s.io_tlsroutes.yaml"
kubectl apply --server-side -f "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/${GATEWAY_CRD_VERSION}/config/crd/standard/gateway.networking.k8s.io_listenersets.yaml"
kubectl apply --server-side -f "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/${GATEWAY_CRD_VERSION}/config/crd/standard/gateway.networking.k8s.io_tcproutes.yaml"
kubectl apply --server-side -f "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/${GATEWAY_CRD_VERSION}/config/crd/standard/gateway.networking.k8s.io_udproutes.yaml"

echo "Installing cilium helm chart"
helm \
  --namespace kube-system \
  upgrade \
  --install \
  --version "${CILIUM_CHART_VERSION}" \
  -f cilium-values.yaml \
  cilium \
  cilium/cilium
