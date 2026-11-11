#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset

cd "$(dirname "$0")"
source common.sh

# Switch to top level directory to access flows
cd ..

install-rollouts-demo() {
  kubectl create namespace jettisonproj --dry-run=client -o yaml | kubectl apply --server-side -f -

  echo "Install rollouts-demo flow"
  kubectl apply --server-side -n jettisonproj -f ./flows/jettisonproj/rollouts-demo-github-pr.yaml
  kubectl apply --server-side -n jettisonproj -f ./flows/jettisonproj/rollouts-demo-github-push.yaml
}

install-deploy-steps() {
  kubectl create namespace jettisonproj --dry-run=client -o yaml | kubectl apply --server-side -f -

  echo "Install deploy-steps flow"
  kubectl apply --server-side -n jettisonproj -f ./flows/jettisonproj/deploy-steps-github-pr.yaml
  kubectl apply --server-side -n jettisonproj -f ./flows/jettisonproj/deploy-steps-github-push.yaml
}

install-wavesmp() {
  kubectl create namespace wavesmp --dry-run=client -o yaml | kubectl apply --server-side -f -

  echo "Install wavesmp flows"
  kubectl apply --server-side -n wavesmp -f ./flows/wavesmp
}

install-jettison-ui() {
  kubectl create namespace jettisonproj --dry-run=client -o yaml | kubectl apply --server-side -f -

  echo "Install jettison ui flows"
  kubectl apply --server-side -n jettisonproj -f ./flows/jettisonproj/jettison-ui-github-pr.yaml
  kubectl apply --server-side -n jettisonproj -f ./flows/jettisonproj/jettison-ui-github-push.yaml
}

install-jettison-controller() {
  kubectl create namespace jettisonproj --dry-run=client -o yaml | kubectl apply --server-side -f -

  echo "Install jettison controller flows"
  kubectl apply --server-side -n jettisonproj -f ./flows/jettisonproj/jettison-controller-github-pr.yaml
  kubectl apply --server-side -n jettisonproj -f ./flows/jettisonproj/jettison-controller-github-push.yaml


  # Handle circular dependency here. Wait for bootstrap to create rollout
  while ! kubectl get -n jettisonproj rollouts jettison-controller-manager; do
    echo "$(date): Waiting for jettison-controller-manager rollout"
    sleep 1
  done
  echo "Waiting for jettison-controller-manager rollout to be available"
  kubectl wait -n jettisonproj rollouts jettison-controller-manager --for=condition=Available --timeout=15m

  # Then, clean up the bootstrap jettison
  echo "Deleting the bootstrap jettison-controller-manager"
  kubectl delete -n jettisonproj deploy/jettison-controller-manager
}


# Install flows
install-rollouts-demo
install-deploy-steps
install-wavesmp
install-jettison-ui
install-jettison-controller
