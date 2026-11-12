#!/bin/bash
#
# Back up devcluster to an S3 bucket including:
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

# Get new backup version
BACKUP_VERSION="$(get_new_backup_version "${BACKUP_PREFIX}")"
BACKUP_URL="${BACKUP_PREFIX}/${BACKUP_VERSION}"
echo "Using backup version ${BACKUP_VERSION}"

# Create temp dir for staging uploads
UPLOAD_DIR="$(mktemp --tmpdir --directory devcluster-backup-XXXXXXX)"
trap 'rm --recursive --force "${UPLOAD_DIR}"' EXIT

# Back up certs
mkdir --parents "${UPLOAD_DIR}/certs/issuers"

# Back up ssl certs for gateway and letsencrypt
kubectl --namespace default get secrets digitalocean-dns letsencrypt letsencrypt-staging osoriano wavesmp -o yaml \
  | grep -v -e 'creationTimestamp: ' -e 'resourceVersion: ' -e 'uid: ' \
  > "${UPLOAD_DIR}/certs/default-secrets.yaml"
# Back up secrets related to argo-events (e.g. github webhook configuration)
kubectl --namespace argo-events get secrets github-access -o yaml \
  | grep -v -e 'creationTimestamp: ' -e 'resourceVersion: ' -e 'uid: ' \
  > "${UPLOAD_DIR}/certs/argo-events-secrets.yaml"
# Back up secrets related to osoriano (e.g. backstage github auth)
kubectl --namespace osoriano get secrets backstage-local-github-oauth backstage-prod-github-oauth -o yaml \
  | grep -v -e 'creationTimestamp: ' -e 'resourceVersion: ' -e 'uid: ' \
  > "${UPLOAD_DIR}/certs/osoriano-secrets.yaml"
# Back up secrets related to argocd (e.g. argocd users)
kubectl --namespace argocd get secrets argocd-initial-admin-secret argocd-readonly-secret -o yaml \
  | grep -v -e 'creationTimestamp: ' -e 'resourceVersion: ' -e 'uid: ' \
  > "${UPLOAD_DIR}/certs/argocd-secrets.yaml"
# Back up secrets related to jettisonproj (e.g. github and docker push)
kubectl --namespace jettisonproj get secrets github-access github-key regcred s3-access argocd-jettisonproj-secret -o yaml \
  | grep -v -e 'creationTimestamp: ' -e 'resourceVersion: ' -e 'uid: ' \
  > "${UPLOAD_DIR}/certs/jettisonproj-secrets.yaml"
# Back up secrets related to wavesmp (e.g. client ids)
kubectl --namespace wavesmp get secrets waves-server-rust-prod waves-client-web -o yaml \
  | grep -v -e 'creationTimestamp: ' -e 'resourceVersion: ' -e 'uid: ' \
  > "${UPLOAD_DIR}/certs/wavesmp-secrets.yaml"

# Back up issuers
kubectl --namespace default get issuers letsencrypt-staging letsencrypt-osoriano letsencrypt-wavesmp -o yaml \
  | grep -v -e 'creationTimestamp: ' -e 'resourceVersion: ' -e 'uid: ' \
  > "${UPLOAD_DIR}/certs/issuers/default-issuers.yaml"

pushd "${UPLOAD_DIR}"
tar --create --gzip --file "${CERTS_TAR}" certs
aws s3 cp --quiet "${CERTS_TAR}" "${BACKUP_URL}/${CERTS_TAR}"
rm --recursive --force "${CERTS_TAR}" certs

# Back up mysql
MYSQL_POD_NAME="$(kubectl --namespace "${MYSQL_NAMESPACE}" get pods --selector app=mysql --output name)"

kubectl --namespace "${MYSQL_NAMESPACE}" exec "${MYSQL_POD_NAME}" -- bash -c "
  set -o errexit
  set -o nounset
  set -o pipefail

  cd '${MYSQL_DUMP_WD}'
  rm --recursive --force '${MYSQL_DUMP_TAR}' '${MYSQL_DUMP_FILE}'
  mysqldump -u root -proot --databases ${MYSQL_NAMES} > '${MYSQL_DUMP_FILE}'
  tar --create --gzip --file '${MYSQL_DUMP_TAR}' '${MYSQL_DUMP_FILE}'
  "
kubectl --namespace "${MYSQL_NAMESPACE}" cp "${MYSQL_POD_NAME##pod/}:${MYSQL_DUMP_WD}/${MYSQL_DUMP_TAR}" "${UPLOAD_DIR}/${MYSQL_DUMP_TAR}"
aws s3 cp --quiet "${UPLOAD_DIR}/${MYSQL_DUMP_TAR}" "${BACKUP_URL}/${MYSQL_DUMP_TAR}"
rm --force "${UPLOAD_DIR}/${MYSQL_DUMP_TAR}"
echo "Backed up mysql"

# Clean up mysql backup files
kubectl --namespace "${MYSQL_NAMESPACE}" exec "${MYSQL_POD_NAME}" -- bash -c "
  set -o errexit
  set -o nounset
  set -o pipefail

  cd '${MYSQL_DUMP_WD}'
  rm --recursive --force '${MYSQL_DUMP_TAR}' '${MYSQL_DUMP_FILE}'
  "

# Back up postgres
POSTGRES_POD_NAME="$(kubectl --namespace "${POSTGRES_NAMESPACE}" get pods --selector app=postgres --output name)"

kubectl --namespace "${POSTGRES_NAMESPACE}" exec "${POSTGRES_POD_NAME}" -- bash -c "
  set -o errexit
  set -o nounset
  set -o pipefail

  cd '${POSTGRES_DUMP_WD}'
  rm --recursive --force '${POSTGRES_DUMP_TAR}' '${POSTGRES_DUMP_FILE}'
  pg_dump --username postgres --dbname ${POSTGRES_NAMES} --file '${POSTGRES_DUMP_FILE}'
  tar --create --gzip --file '${POSTGRES_DUMP_TAR}' '${POSTGRES_DUMP_FILE}'
  "
kubectl --namespace "${POSTGRES_NAMESPACE}" cp "${POSTGRES_POD_NAME##pod/}:${POSTGRES_DUMP_WD}/${POSTGRES_DUMP_TAR}" "${UPLOAD_DIR}/${POSTGRES_DUMP_TAR}"
aws s3 cp --quiet "${UPLOAD_DIR}/${POSTGRES_DUMP_TAR}" "${BACKUP_URL}/${POSTGRES_DUMP_TAR}"
rm --force "${UPLOAD_DIR}/${POSTGRES_DUMP_TAR}"
echo "Backed up postgres"

# Clean up postgres backup files
kubectl --namespace "${POSTGRES_NAMESPACE}" exec "${POSTGRES_POD_NAME}" -- bash -c "
  set -o errexit
  set -o nounset
  set -o pipefail

  cd '${POSTGRES_DUMP_WD}'
  rm --recursive --force '${POSTGRES_DUMP_TAR}' '${POSTGRES_DUMP_FILE}'
  "

# Clean up old backup versions
for old_backup_version in $(get_old_backup_versions "${BACKUP_PREFIX}"); do
  echo "Cleaning up old backup version: ${old_backup_version}"
  aws s3 rm --recursive "${BACKUP_PREFIX}/${old_backup_version}"
done

echo "Backed up devcluster"
popd
