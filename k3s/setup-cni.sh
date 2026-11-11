#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

cd "$(dirname "$0")"
source common.sh

echo "Installing gateway api"
kubectl apply --server-side -f "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/${GATEWAY_CRD_VERSION}/config/crd/standard/gateway.networking.k8s.io_gatewayclasses.yaml"
kubectl apply --server-side -f "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/${GATEWAY_CRD_VERSION}/config/crd/standard/gateway.networking.k8s.io_gateways.yaml"
kubectl apply --server-side -f "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/${GATEWAY_CRD_VERSION}/config/crd/standard/gateway.networking.k8s.io_httproutes.yaml"
kubectl apply --server-side -f "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/${GATEWAY_CRD_VERSION}/config/crd/standard/gateway.networking.k8s.io_referencegrants.yaml"
kubectl apply --server-side -f "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/${GATEWAY_CRD_VERSION}/config/crd/standard/gateway.networking.k8s.io_grpcroutes.yaml"
kubectl apply --server-side -f "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/${GATEWAY_CRD_VERSION}/config/crd/experimental/gateway.networking.k8s.io_tlsroutes.yaml"

echo "Installing cilium helm chart"
helm \
  --namespace kube-system \
  upgrade \
  --install \
  --version "${CILIUM_CHART_VERSION}" \
  -f cilium-values.yaml \
  cilium \
  cilium/cilium
