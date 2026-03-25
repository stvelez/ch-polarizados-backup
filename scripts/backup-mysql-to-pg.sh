#!/bin/sh
# backup.sh — corre dentro del contenedor n8n
set -eu

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="${BACKUP_DIR:-/backups}"
TMP_SQL_FILE="$BACKUP_DIR/ch_polarizados_${TIMESTAMP}.sql"
COMPRESSED_FILE="$BACKUP_DIR/ch_polarizados_${TIMESTAMP}.sql.gz"
VALIDATOR_SCRIPT="${VALIDATOR_SCRIPT:-/scripts/validate-backup.sh}"
MYSQL_SSL="${MYSQL_SSL:-true}"
MYSQL_SSL_VERIFY_SERVER_CERT="${MYSQL_SSL_VERIFY_SERVER_CERT:-false}"
MYSQL_SSL_CA="${MYSQL_SSL_CA:-}"
GPG_PASSPHRASE="${GPG_PASSPHRASE:-}"

mkdir -p "$BACKUP_DIR" "$BACKUP_DIR/weekly" "$BACKUP_DIR/monthly"

echo "Iniciando backup: $TIMESTAMP"

set -- \
  --host="$MYSQL_HOST" \
  --port="$MYSQL_PORT" \
  --user="$MYSQL_USER" \
  --password="$MYSQL_PASSWORD" \
  --single-transaction \
  --routines \
  --triggers \
  --add-drop-table \
  --default-character-set=utf8mb4

if [ "$MYSQL_SSL" = "true" ]; then
  set -- "$@" --ssl
else
  set -- "$@" --skip-ssl
fi

if [ "$MYSQL_SSL_VERIFY_SERVER_CERT" = "true" ]; then
  set -- "$@" --ssl-verify-server-cert
else
  set -- "$@" --skip-ssl-verify-server-cert
fi

if [ -n "$MYSQL_SSL_CA" ]; then
  set -- "$@" --ssl-ca="$MYSQL_SSL_CA"
fi

mysqldump "$@" "$MYSQL_DATABASE" > "$TMP_SQL_FILE"

if [ ! -s "$TMP_SQL_FILE" ]; then
  echo "ERROR: mysqldump no genero contenido" >&2
  rm -f "$TMP_SQL_FILE"
  exit 1
fi

gzip -c "$TMP_SQL_FILE" > "$COMPRESSED_FILE"
# TMP_SQL_FILE se conserva — el workflow lo sube a Drive y luego lo elimina

if [ ! -s "$COMPRESSED_FILE" ]; then
  echo "ERROR: no se pudo crear un backup valido" >&2
  rm -f "$COMPRESSED_FILE"
  exit 1
fi

sh "$VALIDATOR_SCRIPT" "$COMPRESSED_FILE"

# Cifrado GPG opcional — si GPG_PASSPHRASE está definida, cifrar y eliminar el .gz sin cifrar
OUTPUT_FILE="$COMPRESSED_FILE"
if [ -n "$GPG_PASSPHRASE" ]; then
  ENCRYPTED_FILE="${COMPRESSED_FILE}.gpg"
  gpg --batch --yes --symmetric --cipher-algo AES256 \
      --passphrase "$GPG_PASSPHRASE" \
      --output "$ENCRYPTED_FILE" "$COMPRESSED_FILE"
  rm -f "$COMPRESSED_FILE"
  OUTPUT_FILE="$ENCRYPTED_FILE"
  echo "Backup cifrado con GPG: $OUTPUT_FILE"
fi

# Buffer local mínimo: conservar solo los últimos 3 en caso de fallo del workflow
ls -t "$BACKUP_DIR"/ch_polarizados_*.sql.gz* 2>/dev/null | tail -n +4 | xargs -r rm -f
ls -t "$BACKUP_DIR"/ch_polarizados_*.sql 2>/dev/null | tail -n +4 | xargs -r rm -f

# Retención semanal: guardar copia los domingos, conservar últimas 4 semanas
DAY_OF_WEEK=$(date +%u)
if [ "$DAY_OF_WEEK" = "7" ]; then
  cp "$OUTPUT_FILE" "$BACKUP_DIR/weekly/"
  ls -t "$BACKUP_DIR/weekly"/ch_polarizados_*.sql.gz* 2>/dev/null | tail -n +5 | xargs -r rm -f
  echo "Backup semanal guardado"
fi

# Retención mensual: guardar copia el día 1, conservar últimos 3 meses
DAY_OF_MONTH=$(date +%d)
if [ "$DAY_OF_MONTH" = "01" ]; then
  cp "$OUTPUT_FILE" "$BACKUP_DIR/monthly/"
  ls -t "$BACKUP_DIR/monthly"/ch_polarizados_*.sql.gz* 2>/dev/null | tail -n +4 | xargs -r rm -f
  echo "Backup mensual guardado"
fi

FILE_SIZE=$(du -sh "$OUTPUT_FILE" | cut -f1)

echo "BACKUP_OK=true"
echo "BACKUP_FILE=$OUTPUT_FILE"
echo "BACKUP_SQL_FILE=$TMP_SQL_FILE"
echo "BACKUP_SIZE=$FILE_SIZE"
echo "TIMESTAMP=$TIMESTAMP"
