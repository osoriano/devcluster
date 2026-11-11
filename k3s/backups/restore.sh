#!/bin/bash
#
# Restore devcluster from an S3 bucket including:
# - certs
# - mysql
# - postgres
#
# Requirements:
# - aws CLI
#

set -o errexit
set -o nounset
set -o pipefail

cd "$(dirname "$0")"

source common.sh

# Get latest backup version
BACKUP_VERSION="$(get_latest_backup_version "${BACKUP_PREFIX}")"
BACKUP_URL="${BACKUP_PREFIX}/${BACKUP_VERSION}"
echo "Using backup version ${BACKUP_VERSION}"

# Create temp dir for downloads
DL_DIR="$(mktemp --tmpdir --directory devcluster-restore-XXXXXXX)"
trap 'rm --recursive --force "${DL_DIR}"' EXIT

# Restore certs. Overrides existing certs.
# Otherwise, the certs could become outdated
CERTS_DEST="certs"
if [[ -e "${CERTS_DEST}" ]]; then
  echo "Certs already present in ${CERTS_DEST}. Removing..."
  rm -rf "${CERTS_DEST}"
fi

aws s3 cp --quiet "${BACKUP_URL}/${CERTS_TAR}" "${DL_DIR}/${CERTS_TAR}"
tar xC "${DL_DIR}" -f "${DL_DIR}/${CERTS_TAR}"
rm "${DL_DIR}/${CERTS_TAR}"
mv "${DL_DIR}"/certs "${CERTS_DEST}"
echo "Restored certs"

# Restore the mysql volume if not present
MYSQL_PVC_NAME="$(kubectl --namespace "${MYSQL_NAMESPACE}" get pvc/mysql --output name --ignore-not-found)"

if [[ -n "${MYSQL_PVC_NAME}" ]]; then
  echo "pvc/mysql already present. Skipping mysql restore"
else
  echo "Restoring mysql"

  kubectl --namespace "${MYSQL_NAMESPACE}" create namespace "${MYSQL_NAMESPACE}" --dry-run=client -o yaml | kubectl apply --server-side -f -
  kubectl --namespace "${MYSQL_NAMESPACE}" apply --server-side -f ./mysql-pvc.yaml
  kubectl --namespace "${MYSQL_NAMESPACE}" apply --server-side -f ./mysql-deployment.yaml

  kubectl --namespace "${MYSQL_NAMESPACE}" wait deployments --all --for=condition=Available --timeout=15m

  MYSQL_POD_NAME="$(kubectl --namespace "${MYSQL_NAMESPACE}" get pods --selector app=mysql --output name)"

  # Restore mysql data
  aws s3 cp --quiet "${BACKUP_URL}/${MYSQL_DUMP_TAR}" "${DL_DIR}/${MYSQL_DUMP_TAR}"
  kubectl --namespace "${MYSQL_NAMESPACE}" cp "${DL_DIR}/${MYSQL_DUMP_TAR}" "${MYSQL_POD_NAME##pod/}:${MYSQL_DUMP_WD}/${MYSQL_DUMP_TAR}"
  rm "${DL_DIR}/${MYSQL_DUMP_TAR}"
  kubectl --namespace "${MYSQL_NAMESPACE}" exec "${MYSQL_POD_NAME}" -- bash -c "
    set -o errexit
    set -o nounset
    set -o pipefail

    echo 'Waiting for mysql to come up'

    while ! timeout 2 bash -c '< /dev/tcp/localhost/${MYSQL_PORT}' > /dev/null 2>&1; do
        echo 'Waiting for port ${MYSQL_PORT} to listen'
        sleep 3
    done

    cd '${MYSQL_DUMP_WD}'
    tar xf '${MYSQL_DUMP_TAR}'
    mysql -u root -proot < '${MYSQL_DUMP_FILE}'
    rm '${MYSQL_DUMP_FILE}' '${MYSQL_DUMP_TAR}'

    echo 'Restored mysql'
    "

    kubectl --namespace "${MYSQL_NAMESPACE}" apply --server-side -f ./mysql-service.yaml
fi

# Restore the postgres volume if not present
POSTGRES_PVC_NAME="$(kubectl --namespace "${POSTGRES_NAMESPACE}" get pvc/postgres --output name --ignore-not-found)"

if [[ -n "${POSTGRES_PVC_NAME}" ]]; then
  echo "pvc/postgres already present. Skipping postgres restore"
else
  echo "Restoring postgres"

  kubectl --namespace "${POSTGRES_NAMESPACE}" create namespace "${POSTGRES_NAMESPACE}" --dry-run=client -o yaml | kubectl apply --server-side -f -
  kubectl --namespace "${POSTGRES_NAMESPACE}" apply --server-side -f ./postgres-pvc.yaml
  kubectl --namespace "${POSTGRES_NAMESPACE}" apply --server-side -f ./postgres-deployment.yaml

  kubectl --namespace "${POSTGRES_NAMESPACE}" wait deployments --all --for=condition=Available --timeout=15m

  POSTGRES_POD_NAME="$(kubectl --namespace "${POSTGRES_NAMESPACE}" get pods --selector app=postgres --output name)"

  # Restore postgres data
  aws s3 cp --quiet "${BACKUP_URL}/${POSTGRES_DUMP_TAR}" "${DL_DIR}/${POSTGRES_DUMP_TAR}"
  kubectl --namespace "${POSTGRES_NAMESPACE}" cp "${DL_DIR}/${POSTGRES_DUMP_TAR}" "${POSTGRES_POD_NAME##pod/}:${POSTGRES_DUMP_WD}/${POSTGRES_DUMP_TAR}"
  rm "${DL_DIR}/${POSTGRES_DUMP_TAR}"
  kubectl --namespace "${POSTGRES_NAMESPACE}" exec "${POSTGRES_POD_NAME}" -- bash -c "
    set -o errexit
    set -o nounset
    set -o pipefail

    echo 'Waiting for postgres to come up'

    while ! timeout 2 bash -c '< /dev/tcp/localhost/${POSTGRES_PORT}' > /dev/null 2>&1; do
        echo 'Waiting for port ${POSTGRES_PORT} to listen'
        sleep 3
    done

    cd '${POSTGRES_DUMP_WD}'
    tar xf '${POSTGRES_DUMP_TAR}'
    psql --username postgres --dbname ${POSTGRES_NAMES} --file '${POSTGRES_DUMP_FILE}'
    rm '${POSTGRES_DUMP_FILE}' '${POSTGRES_DUMP_TAR}'

    echo 'Restored postgres'
    "

    kubectl --namespace "${POSTGRES_NAMESPACE}" apply --server-side -f ./postgres-service.yaml
fi

echo "Restored devcluster"
