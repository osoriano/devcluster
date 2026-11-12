# CLAUDE.md

Scripts and manifests that build a single-node k3s dev cluster, restore its state from S3, and install the Jettison CI/CD system and the apps it deploys. The cluster serves real public sites (`*.osoriano.com`, `wavesmusicplayer.com`), so treat it as production-adjacent.

## Bring-up order

`k3s/start.sh` runs everything, in this order. Later steps depend on earlier ones:

1. `create.sh`: installs k3s with flannel, kube-proxy, network policy, and traefik disabled (`INSTALL_K3S_EXEC` in `common.sh`).
2. `setup-cni.sh`: Gateway API CRDs, then Cilium (kube-proxy replacement, Gateway API in host-network mode).
3. `validate.sh`: downloads the Cilium CLI to `k3s/bin/` and waits for `cilium status`.
4. `backups/restore.sh`: pulls the latest S3 backup, extracts secrets to `k3s/backups/certs/` (gitignored), and restores MySQL and Postgres only if their PVCs don't exist yet.
5. Creates namespaces, applies the restored secrets, installs cert-manager, then applies the issuers and Certificates.
6. `install-apps.sh`: Headlamp, kube-prometheus, Argo CD, Argo Workflows, NATS JetStream, Argo Events, Argo Rollouts, the personal site, and the bootstrap Jettison controller.
7. `install-flows.sh`: applies the Flow resources from `flows/`, waits for the Jettison-deployed controller Rollout, then deletes the bootstrap Deployment.
8. Applies `apps/gateway/default-gateway.yaml`.

`k3s/cleanup.sh` backs up to S3, uninstalls k3s, and flushes all host iptables and ip6tables rules.

## Key constraints

- **The cluster can't be built from scratch without an S3 backup.** `install-argocd` reads restored secrets (`argocd-initial-admin-secret`, `argocd-readonly-secret`, `jettisonproj/argocd-jettisonproj-secret`), and Argo Workflows needs the `argo` MySQL database from the restore. Jettison needs `github-access`, `github-key`, `regcred`, and `s3-access` in `jettisonproj`. Its `secretbuilder` copies them into other flow namespaces.
- **Jettison bootstrap circular dependency.** Jettison deploys itself. `install-apps.sh` installs `dist/install.yaml` from `jettisonproj/jettison-controller`, with the image pinned to the version label in `jettisonproj/jettison-argo-configs` `prod/controller/controller-rollout.yaml`. That bootstrap controller processes the `jettison-controller-github-push` Flow, whose ArgoCD step creates the real `jettison-controller-manager` Rollout. After that, the bootstrap Deployment is deleted. If the prod flow is paused, `install-flows.sh` waits indefinitely; `dev-scripts/sync-jettison-controller.sh` forces the Argo CD sync.
- **Adding a new secret that must survive rebuilds** means adding it to the matching `kubectl get secrets ...` line in `k3s/backups/backup.sh`. Otherwise it is lost on the next `cleanup.sh` and `start.sh` cycle.
- `kubectl apply -f ./backups/certs` is intentionally non-recursive. `issuers/` is applied later, once cert-manager's CRDs exist.
- The Argo Events `EventBus` is applied separately from its kustomization because its CRD must be established first.
- kube-prometheus is applied without `--server-side` (known upstream issue). Its NetworkPolicies are deleted afterward on purpose.

## External dependencies

- `~/gh/prometheus-operator/kube-prometheus`: `install-kube-prometheus.sh` runs `git fetch && git rebase origin/main` in this clone.
- `~/gh/osoriano/site/k8s`: applied as-is for the personal site.
- Helm repos: `cilium`, `nats`, `headlamp`. Tools: `helm`, `jq`, `yq`, `htpasswd`, `aws` (configured for the backup bucket).
- Sibling repos under `~/gh/jettisonproj/` (`jettison-controller`, `jettison-argo-configs`, and others) are useful for answering questions about Flow behavior.

## Exposing a new app

Every public hostname needs three pieces, kept consistent:

1. An HTTPS listener in `apps/gateway/default-gateway.yaml` that uses the `osoriano` or `wavesmp` TLS secret and allows only the app's namespace (`kubernetes.io/metadata.name` selector).
2. An `https-route` HTTPRoute whose `sectionName` is that listener.
3. An `http-route` HTTPRoute on the shared `http-gw` listener that 301-redirects to HTTPS.

The Certificates are wildcards (`*.osoriano.com`, `*.wavesmusicplayer.com`), so a new subdomain doesn't need cert changes.

## Adding a Jettison-managed app

Add `<repo>-github-pr.yaml` and `<repo>-github-push.yaml` Flow manifests under `flows/<github-org>/`, then add an install function to `k3s/install-flows.sh`. The `jettisonproj` flows set `metadata.namespace` directly. The `wavesmp` flows don't, and rely on `-n wavesmp`.

## Conventions

- Scripts use `set -o errexit -o nounset -o pipefail`, `cd "$(dirname "$0")"`, and `source common.sh`. They use `kubectl apply --server-side` and create namespaces idempotently with `kubectl create namespace X --dry-run=client -o yaml | kubectl apply --server-side -f -`.
- Every workload gets small resource requests and memory limits through a `resources-patch.yaml` (or Helm values), because this is a single small node.
- Pinned versions live in `k3s/common.sh` (Cilium chart and CLI, Gateway CRDs) and in `apps/cert-manager/kustomization.yaml`. The Argo components track `stable` or `latest` upstream.
- Generated logins go to `output/` (gitignored). Never commit secrets; the one exception is the dev-only MySQL credentials in `apps/argo-workflows/argo-mysql-config.yaml`.
- Set `KUBECONFIG=/etc/rancher/k3s/k3s.yaml` (or `source dev-scripts/dev-init.sh`) before running `kubectl` by hand.

## Validating changes

There are no tests. To check manifests offline:

- `kubectl kustomize apps/<app>` builds a kustomization.
- `kubectl apply --dry-run=server` checks manifests against a running cluster.

Don't run `start.sh`, `cleanup.sh`, `backup.sh`, or `restore.sh` without asking. They reinstall the host cluster, rewrite the firewall, and read or write the shared S3 backups.
