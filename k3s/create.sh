#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

cd "$(dirname "$0")"
source common.sh


echo "Creating k3s cluster"
req \
  --location \
  https://get.k3s.io \
  | sh -

sudo chown -R "${USER}:${USER}" /etc/rancher/k3s
