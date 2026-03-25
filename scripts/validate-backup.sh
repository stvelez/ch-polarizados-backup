#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
  echo "Uso: sh scripts/validate-backup.sh backups/archivo.sql.gz" >&2
  exit 1
fi

BACKUP_FILE="$1"

if [ ! -f "$BACKUP_FILE" ]; then
  echo "ERROR: no existe el archivo: $BACKUP_FILE" >&2
  exit 1
fi

case "$BACKUP_FILE" in
  *.sql.gz) ;;
  *)
    echo "ERROR: el archivo debe terminar en .sql.gz" >&2
    exit 1
    ;;
esac

echo "Validando: $BACKUP_FILE"

if ! gzip -t "$BACKUP_FILE"; then
  echo "ERROR: el archivo gzip esta corrupto" >&2
  exit 1
fi

COMPRESSED_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
UNCOMPRESSED_BYTES=$(gunzip -c "$BACKUP_FILE" | wc -c | tr -d ' ')
HEADER_SAMPLE=$(gunzip -c "$BACKUP_FILE" | sed -n '1,40p')

if [ "$UNCOMPRESSED_BYTES" -eq 0 ]; then
  echo "ERROR: el backup esta vacio" >&2
  exit 1
fi

if ! printf '%s\n' "$HEADER_SAMPLE" | grep -Eq 'CREATE TABLE|INSERT INTO|DROP TABLE|-- (MariaDB|MySQL) dump'; then
  echo "ERROR: el contenido no parece un dump SQL valido" >&2
  exit 1
fi

echo "OK: backup valido"
echo "Archivo: $BACKUP_FILE"
echo "Tamano comprimido: $COMPRESSED_SIZE"
echo "Tamano descomprimido: ${UNCOMPRESSED_BYTES} bytes"
echo "Primeras lineas:"
printf '%s\n' "$HEADER_SAMPLE" | sed -n '1,8p'
