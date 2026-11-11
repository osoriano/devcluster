BACKUP_BUCKET=backups.wavesmusicplayer.com
BACKUP_PREFIX="s3://${BACKUP_BUCKET}/devcluster"

BACKUP_VERSION_REGEX='^\d{3}$'
BACKUP_VERSION_FORMAT='%03d'
BACKUP_VERSIONS_TO_KEEP=10

MYSQL_NAMES="waves argo"
MYSQL_PORT=3306
MYSQL_DUMP_WD=/root
MYSQL_DUMP_TAR=mysql-dump.tar.gz
MYSQL_DUMP_FILE=mysql-dump.sql
MYSQL_NAMESPACE=mysql

POSTGRES_NAMES="backstage"
POSTGRES_PORT=5432
POSTGRES_DUMP_WD=/root
POSTGRES_DUMP_TAR=postgres-dump.tar.gz
POSTGRES_DUMP_FILE=postgres-dump.sql
POSTGRES_NAMESPACE=postgres

CERTS_TAR=certs.tar.gz

get_backup_versions() {
  local prefix="$1"
  aws s3 ls "${prefix}/" | \
    grep PRE | \
    awk '{ print $2 }' | \
    tr -d / | \
    grep -P "${BACKUP_VERSION_REGEX}"  | \
    sort
}

get_latest_backup_version() {
  local prefix="$1"
  get_backup_versions "${prefix}" | tail -n 1
}

get_new_backup_version() {
  local prefix="$1"
  local backup_version="$(get_latest_backup_version "${prefix}")"

  if [[ -z "${backup_version}" ]]; then
    echo -n 000
  else
    backup_version="$((10#${backup_version} + 1))"
    printf "${BACKUP_VERSION_FORMAT}" "${backup_version}"
  fi
}

get_old_backup_versions() {
  local prefix="$1"
  get_backup_versions "${prefix}" | head "-n-${BACKUP_VERSIONS_TO_KEEP}"
}
