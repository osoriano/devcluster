#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

cd "$(dirname "$0")"
source common.sh

LATEST_CILIUM_CLI_VERSION="$(
  req \
    https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt
)"

if [[ "${CILIUM_CLI_VERSION}" != "${LATEST_CILIUM_CLI_VERSION}" ]]; then
  echo "Newer cilium version available: ${LATEST_CILIUM_CLI_VERSION}"
  echo "Consider upgrading"
fi

if [[ ! -f bin/cilium ]]; then
  echo "Downloading cilium CLI"

  mkdir -p bin
  pushd bin

  req \
    --location \
    --remote-name-all \
    https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-amd64.tar.gz{,.sha256sum}

  sha256sum --check cilium-linux-amd64.tar.gz.sha256sum
  tar xzvf cilium-linux-amd64.tar.gz
  rm cilium-linux-amd64.tar.gz{,.sha256sum}

  popd
fi

echo "Waiting for cilium status"
bin/cilium status --wait

# Currently 1 test fails. Needs investigation:
# no-unexpected-packet-drops
#
# echo "Running cilium connectivity test"
# bin/cilium connectivity test
#
# echo "Cilium tests passed. Cleaning up..."
# kubectl delete namespace cilium-test
