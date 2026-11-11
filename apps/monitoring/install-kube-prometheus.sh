#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset


# Fetch latest manifests repo
cd ~/gh/prometheus-operator/kube-prometheus
git fetch
git rebase origin/main

# Create the namespace and CRDs
kubectl apply --server-side -f manifests/setup

# Wait for them to be availble before creating the remaining resources
while ! kubectl get servicemonitors --all-namespaces; do
  echo "$(date): Waiting for servicemonitors to come up"
  sleep 1
done

# --server-side does not work here.
# See:
# - https://github.com/prometheus-operator/kube-prometheus/issues/2145
# - https://github.com/prometheus-operator/kube-prometheus/issues/2145
kubectl apply -f manifests/

# Reduce resource usage by applying a patch rather than using
# jsonnet, which kube-prometheus uses
kubectl -n monitoring patch prometheus k8s --type merge \
  -p '{"spec":{"replicas":1,"retention":"3d","resources":{"requests":{"cpu":"100m","memory":"1536Mi"}}}}'
kubectl -n monitoring patch alertmanager main --type merge \
  -p '{"spec":{"replicas":1}}'
kubectl -n monitoring scale deployment prometheus-adapter --replicas=1
