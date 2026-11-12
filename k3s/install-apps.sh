#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset

cd "$(dirname "$0")"
source common.sh

# Switch to top level directory to access apps
cd ..
OUTPUT_DIR=./output
mkdir -p "${OUTPUT_DIR}"

install-headlamp() {
  echo "Install headlamp"

  helm --namespace kube-system upgrade --install headlamp headlamp/headlamp --values ./apps/headlamp/values.yaml

  kubectl apply --server-side -n kube-system -f ./apps/headlamp/auth/secret-headlamp-admin-user.yaml
  kubectl apply --server-side -n kube-system -f ./apps/headlamp/routes

  HEADLAMP_ADMIN_TOKEN="$(kubectl -n kube-system get secret/headlamp -o=jsonpath='{.data.token}' | base64 --decode)"
  echo "💻 See ${OUTPUT_DIR}/headlamp.txt for headlamp UI login"
  echo "Bearer ${HEADLAMP_ADMIN_TOKEN}" > "${OUTPUT_DIR}/headlamp.txt"
}

install-monitoring() {
  echo "Install monitoring components"
  ./apps/monitoring/install-kube-prometheus.sh
  kubectl apply --server-side -f ./apps/monitoring/routes
  # Easier to delete NetworkPolicy than to configure prometheus using jsonnet
  # See https://github.com/prometheus-operator/kube-prometheus/issues/1763
  kubectl --namespace monitoring delete networkpolicies --all
  echo "💻 For monitoring, use credentials admin:admin"
}

# Install argocd with 3 users:
# - admin
# - readonly
# - jettisonproj
install-argocd() {
  echo "Install argocd"
  ARGO_CD_ADMIN_PASS="$(
    kubectl --namespace argocd get secrets/argocd-initial-admin-secret -o json \
      | jq -r .data.password \
      | base64 --decode
  )"
  ARGO_CD_ADMIN_PASS_HASH="$(htpasswd -bnBC 10 "" "${ARGO_CD_ADMIN_PASS}" | tr -d ':\n')"

  ARGO_CD_JETTISON_PASS="$(
    kubectl --namespace jettisonproj get secrets/argocd-jettisonproj-secret -o json \
      | jq -r .data.password \
      | base64 --decode
  )"
  ARGO_CD_JETTISON_PASS_HASH="$(htpasswd -bnBC 10 "" "${ARGO_CD_JETTISON_PASS}" | tr -d ':\n')"

  ARGO_CD_READONLY_PASS="$(
    kubectl --namespace argocd get secrets/argocd-readonly-secret -o json \
      | jq -r .data.password \
      | base64 --decode
  )"
  ARGO_CD_READONLY_PASS_HASH="$(htpasswd -bnBC 10 "" "${ARGO_CD_READONLY_PASS}" | tr -d ':\n')"

  kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply --server-side -f -
  kubectl --namespace argocd apply --server-side -k ./apps/argocd
  kubectl --namespace argocd apply --server-side -f ./apps/argocd/routes
  kubectl --namespace argocd apply --server-side -f ./apps/argocd/projects
  kubectl --namespace argocd patch secret argocd-secret \
    -p '{"stringData": {
      "admin.password": "'${ARGO_CD_ADMIN_PASS_HASH}'",
      "accounts.jettisonproj.password": "'${ARGO_CD_JETTISON_PASS_HASH}'",
      "accounts.readonly.password": "'${ARGO_CD_READONLY_PASS_HASH}'" }}'

  echo "💻 See ${OUTPUT_DIR}/argocd.txt for argocd login"
  echo "user: admin" > "${OUTPUT_DIR}/argocd.txt"
  echo "pass: ${ARGO_CD_ADMIN_PASS}" >> "${OUTPUT_DIR}/argocd.txt"
  echo "user: readonly" >> "${OUTPUT_DIR}/argocd.txt"
  echo "pass: ${ARGO_CD_READONLY_PASS}" >> "${OUTPUT_DIR}/argocd.txt"
  echo "user: jettisonproj" >> "${OUTPUT_DIR}/argocd.txt"
  echo "pass: ${ARGO_CD_JETTISON_PASS}" >> "${OUTPUT_DIR}/argocd.txt"
}

install-argo-workflows() {
  echo "Install argo workflows"
  kubectl create namespace argo --dry-run=client -o yaml | kubectl apply --server-side -f -
  kubectl apply --server-side -n argo -k ./apps/argo-workflows
  kubectl apply --server-side -n argo -f ./apps/argo-workflows/auth/clusterrole-argo-ui-user.yaml
  kubectl apply --server-side -n argo -f ./apps/argo-workflows/auth/clusterrolebinding-argo-ui-user.yaml
  kubectl apply --server-side -n argo -f ./apps/argo-workflows/auth/serviceaccount-argo-ui-user.yaml
  kubectl apply --server-side -n argo -f ./apps/argo-workflows/auth/secret-argo-ui-user.yaml
  kubectl apply --server-side -n argo -f ./apps/argo-workflows/routes
  ARGO_WORKFLOWS_TOKEN="$(kubectl -n argo get secret/argo-ui-user -o=jsonpath='{.data.token}' | base64 --decode)"
  echo "💻 See ${OUTPUT_DIR}/argo.txt for argo UI login"
  echo "Bearer ${ARGO_WORKFLOWS_TOKEN}" > "${OUTPUT_DIR}/argo.txt"
}

# Dependency for argo-events
install-nats-jetstream() {
  echo "Install NATS Jetstream"
  kubectl create namespace nats --dry-run=client -o yaml | kubectl apply --server-side -f -
  helm --namespace nats upgrade --install nats nats/nats \
    --set config.jetstream.enabled=true \
    --set config.jetstream.fileStore.pvc.size=2Gi \
    --set reloader.enabled=false \
    --set natsBox.enabled=false \
    --set container.resources.requests.cpu=50m \
    --set container.resources.requests.memory=64Mi \
    --set container.resources.limits.memory=256Mi
}

install-argo-events() {
  echo "Install argo events"
  kubectl create namespace argo-events --dry-run=client -o yaml | kubectl apply --server-side -f -
  kubectl apply --server-side -n argo-events -k ./apps/argo-events/base
  kubectl apply --server-side -n argo-events -f ./apps/argo-events/routes
  kubectl apply --server-side -n argo-events -f ./apps/argo-events/base/eventbus.yaml
}

install-argo-rollouts() {
  echo "Install argo rollouts"
  kubectl create namespace argo-rollouts --dry-run=client -o yaml | kubectl apply --server-side -f -
  kubectl apply --server-side -n argo-rollouts -k ./apps/argo-rollouts
  kubectl apply --server-side -n argo-rollouts -f ./apps/argo-rollouts/clusterrole-gateway-controller.yaml
  kubectl apply --server-side -n argo-rollouts -f ./apps/argo-rollouts/clusterrolebinding-gateway-admin.yaml
}

install-site() {
  echo "Install personal site"
  kubectl apply --server-side -f ~/gh/osoriano/site/k8s
}

install-jettison-bootstrap() {
  echo "Install Jettison Controller (bootstrap version)"

  JETTISON_BOOTSTRAP_VERSION="$(
    req https://raw.githubusercontent.com/jettisonproj/jettison-argo-configs/refs/heads/main/prod/controller/controller-rollout.yaml \
      | yq -r '.metadata.labels["app.kubernetes.io/version"]'
  )"

  JETTISON_BOOTSTRAP_DIR="$(mktemp --tmpdir --directory jettison-bootstrap-XXXXXXX)"
  trap 'rm --recursive --force "${JETTISON_BOOTSTRAP_DIR}"' EXIT

  req https://raw.githubusercontent.com/jettisonproj/jettison-controller/refs/heads/main/dist/install.yaml \
    | sed "s|ghcr.io/jettisonproj/jettison-controller:latest|ghcr.io/jettisonproj/jettison-controller:${JETTISON_BOOTSTRAP_VERSION}|g" \
    > "${JETTISON_BOOTSTRAP_DIR}/jettison-install.yaml"

  kubectl apply --server-side --namespace jettisonproj -f "${JETTISON_BOOTSTRAP_DIR}/jettison-install.yaml"
}

# Install apps
install-headlamp
install-monitoring
install-argocd
install-argo-workflows
install-nats-jetstream
install-argo-events
install-argo-rollouts
install-site
install-jettison-bootstrap
