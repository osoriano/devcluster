# devcluster

Create a Kubernetes development cluster using k3s

# Prerequisites

- [Helm](https://helm.sh/docs/intro/install/)
- `helm repo add cilium https://helm.cilium.io/`
- `helm repo add grafana https://grafana.github.io/helm-charts`
- `helm repo add nats https://nats-io.github.io/k8s/helm/charts/`
- `helm repo add headlamp https://kubernetes-sigs.github.io/headlamp/`
- `helm repo update`
- [kube-prometheus](https://github.com/prometheus-operator/kube-prometheus) cloned into ~/gh/prometheus-operator/kube-prometheus
- [osoriano/site](https://github.com/osoriano/site) cloned into ~/gh/osoriano/site
- Tools: `jq`, `yq`, `htpasswd`
- `aws` - CLI for accessing backups on S3

# Instructions

To start the cluster, run:

```
./k3s/start.sh
```

To clean up the cluster, run:
```
./k3s/cleanup.sh
```

# Accessing the Cluster

Run this command to ensure the `KUBECONFIG` points to the correct file:

```
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
```

Then, the cluster can be accessed with `kubectl`
