#!/bin/bash

# Enforces strict mode
set -euo pipefail

# Function definitions
cleanup() {
  echo "Cleaning up..."
  rm -rf "${WORKING_DIR}"
}

# Constants
readonly BACKUP_DIR="/home/odoo/backups"
readonly BASE_FILESTORE_PATH="/home/odoo/data/filestore"


#parameters: 
# DATABASE
# NEW_DB_NAME
#
if [[ "$#" -ne 2 ]]; then
  echo "Usage: $0 <database_name> <new_database_name>"
  exit 1
fi


readonly DATABASE="$1"
readonly DB_NAME="$2"
readonly FILESTORE_PATH="${BASE_FILESTORE_PATH}/${DB_NAME}"
readonly WORKING_DIR="/tmp/odoo_restore_${DATABASE}_$(date +%Y%m%d%H%M%S)"

echo "${DB_NAME}"

# Setup trap for cleaning up on error
trap cleanup ERR

# Export PGPASSWORD for non-interactive postgres operations
export PGPASSWORD="${PASSWORD}"

# Find the most recent backup file
readonly LATEST_BACKUP=$(find "${BACKUP_DIR}" -name "${DATABASE}_*.zip" -print | sort -r | head -1)

if [[ -z "${LATEST_BACKUP}" ]]; then
  echo "No backup found for database ${DATABASE}."
  exit 1
fi

# Prepare working directory
mkdir -p "${WORKING_DIR}"

echo "Restoring from ${LATEST_BACKUP}..."

# Extract backup
unzip "${LATEST_BACKUP}" -d "${WORKING_DIR}" 

# Drop the existing database if it exists
echo "Dropping existing database (if it exists)..."
dropdb --if-exists --force -h "${HOST}" -U "${USER}" "${DB_NAME}"

# Create the database
echo "Creating the database..."
createdb -h "${HOST}" -U "${USER}" "${DB_NAME}"

# Restore database from the sql dump file
echo "Restoring the database..."
# pg_restore --exit-on-error --verbose -h "${HOST}" -U "${USER}" -d "${DATABASE}" "${WORKING_DIR}/dump.sql"
psql -U "${USER}" "${DB_NAME}" < "${WORKING_DIR}/dump.sql"


# Remove existing filestore if it exists
if [[ -d "${FILESTORE_PATH}" ]]; then
  echo "Removing existing filestore..."
  rm -rf "${FILESTORE_PATH}"
fi

# Restore filestore
echo "Restoring the filestore..."
cp -r "${WORKING_DIR}/filestore" "${FILESTORE_PATH}"

# Cleanup after successful execution
cleanup

echo "Restore completed successfully."
