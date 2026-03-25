#!/bin/sh
# backup-mysql-to-pg.sh
# Este script corre DENTRO del contenedor n8n
# Lo ejecuta n8n via el nodo "Execute Command"

set -eu

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="${BACKUP_DIR:-/backups}"
MYSQL_DUMP_FILE="$BACKUP_DIR/mysql_dump_${TIMESTAMP}.sql"
PG_DUMP_FILE="$BACKUP_DIR/pg_dump_${TIMESTAMP}.sql"
FINAL_FILE="$BACKUP_DIR/ch_polarizados_backup_${TIMESTAMP}.sql.gz"

echo "=== Iniciando backup CH Polarizados ==="
echo "Timestamp: $TIMESTAMP"

# 1. Crear directorio si no existe
mkdir -p "$BACKUP_DIR"

# 2. Dump MySQL completo (estructura + datos)
echo "--- Exportando MySQL..."
mysqldump \
  --host="$MYSQL_HOST" \
  --port="$MYSQL_PORT" \
  --user="$MYSQL_USER" \
  --password="$MYSQL_PASSWORD" \
  --single-transaction \
  --routines \
  --triggers \
  --events \
  --add-drop-table \
  --complete-insert \
  --default-character-set=utf8mb4 \
  "$MYSQL_DATABASE" > "$MYSQL_DUMP_FILE"

echo "--- Dump MySQL OK: $MYSQL_DUMP_FILE ($(du -sh "$MYSQL_DUMP_FILE" | cut -f1))"

# 3. Convertir MySQL dump a sintaxis PostgreSQL
echo "--- Convirtiendo a PostgreSQL..."
cat "$MYSQL_DUMP_FILE" | \
  # Remover comentarios específicos de MySQL
  grep -v "^-- MySQL dump" | \
  grep -v "^-- Host:" | \
  grep -v "^-- Server version" | \
  grep -v "^/*!40" | \
  grep -v "^/*!50" | \
  # Reemplazar tipos MySQL -> PostgreSQL
  sed 's/ENGINE=InnoDB[^;]*//g' | \
  sed 's/ENGINE=MyISAM[^;]*//g' | \
  sed 's/AUTO_INCREMENT=[0-9]* //g' | \
  sed 's/ AUTO_INCREMENT//' | \
  sed 's/`/"/g' | \
  sed 's/int(11)/INTEGER/g' | \
  sed 's/int(10) unsigned/INTEGER/g' | \
  sed 's/tinyint(1)/BOOLEAN/g' | \
  sed 's/tinyint([0-9]*)/SMALLINT/g' | \
  sed 's/mediumtext/TEXT/g' | \
  sed 's/longtext/TEXT/g' | \
  sed 's/mediumblob/BYTEA/g' | \
  sed 's/longblob/BYTEA/g' | \
  sed 's/blob/BYTEA/g' | \
  sed 's/datetime/TIMESTAMP/g' | \
  sed 's/UNSIGNED //g' | \
  sed "s/\\\\'/\'\'/g" | \
  sed 's/DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP/DEFAULT CURRENT_TIMESTAMP/g' \
  > "$PG_DUMP_FILE"

echo "--- Conversión OK: $PG_DUMP_FILE"

# 4. Comprimir el dump PostgreSQL
echo "--- Comprimiendo..."
gzip -c "$PG_DUMP_FILE" > "$FINAL_FILE"

# 5. Limpiar archivos temporales
rm -f "$MYSQL_DUMP_FILE" "$PG_DUMP_FILE"

# 6. Rotar backups: mantener solo los últimos 7
echo "--- Rotando backups (manteniendo últimos 7)..."
ls -t "$BACKUP_DIR"/ch_polarizados_backup_*.sql.gz 2>/dev/null | tail -n +8 | xargs -r rm -f

echo "=== Backup completado: $FINAL_FILE ==="
echo "BACKUP_FILE=$FINAL_FILE"
echo "BACKUP_SIZE=$(du -sh "$FINAL_FILE" | cut -f1)"
echo "TIMESTAMP=$TIMESTAMP"
