#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset

cd "$(dirname "$0")"

./create.sh
./setup-cni.sh
./validate.sh

echo "Waiting for kube-system to start"
kubectl --namespace kube-system wait deployments --all --for=condition=Available --timeout=15m

echo "Restore database and certs from backup"
./backups/restore.sh

echo "Restoring certs"
kubectl create namespace argo-events      --dry-run=client -o yaml | kubectl apply --server-side -f -
kubectl create namespace argocd           --dry-run=client -o yaml | kubectl apply --server-side -f -
kubectl create namespace osoriano         --dry-run=client -o yaml | kubectl apply --server-side -f -
kubectl create namespace jettisonproj     --dry-run=client -o yaml | kubectl apply --server-side -f -
kubectl create namespace wavesmp          --dry-run=client -o yaml | kubectl apply --server-side -f -
kubectl apply --server-side -f ./backups/certs

echo "Starting cert-manager"
kubectl apply --server-side -k ../apps/cert-manager

echo "Waiting for cert-manager to start"
kubectl --namespace cert-manager wait deployments --all --for=condition=Available --timeout=15m

echo "Configuring cert refresh"
kubectl apply --server-side -f ./backups/certs/issuers/default-issuers.yaml
kubectl apply --server-side -f ../apps/cert-manager/cert-wavesmp.yaml
kubectl apply --server-side -f ../apps/cert-manager/cert-osoriano.yaml

echo "Configuring apps"
./install-apps.sh

echo "Configuring flows"
./install-flows.sh

echo "Creating gateway"
kubectl apply --server-side -f ../apps/gateway/default-gateway.yaml
