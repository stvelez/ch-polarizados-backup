# CH Polarizados - MySQL Backup Diario con n8n

Backup automatico diario a las 2am (hora Bogota).
El dump comprimido se guarda en `./backups/` y se conservan los ultimos 7 archivos.

## Estructura real del repo

```text
n8n-backup/
├── Dockerfile
├── docker-compose.yml
├── .env
├── .env.example
├── backups/
├── scripts/
│   └── backup-mysql-to-pg.sh
└── workflows/
    └── ch-polarizados-backup.json
```

`scripts/` y `workflows/` son las rutas canonicas. Los archivos duplicados en la raiz quedaron como copias legacy y no son los que usa `docker-compose.yml`.

## Setup

### 1. Configurar `.env`

```bash
cp .env.example .env
```

Completa el password real:

```bash
MYSQL_PASSWORD=tu_password_aqui
MYSQL_SSL=true
MYSQL_SSL_VERIFY_SERVER_CERT=false
```

### 2. Dar permisos al script

```bash
chmod +x scripts/backup-mysql-to-pg.sh
```

### 3. Construir y levantar

```bash
docker compose build
docker compose up -d
```

### 4. Importar el workflow en n8n

1. Abrir http://localhost:5678
2. Crear cuenta si es la primera vez.
3. Ir a **Workflows -> Import from file**.
4. Importar `workflows/ch-polarizados-backup.json`.
5. Activar el workflow.

### 5. Probar manualmente

Ejecuta el workflow desde n8n con **Execute Workflow**.
Si todo sale bien, aparecera un archivo como este en `./backups/`:

```text
ch_polarizados_20260323_020000.sql.gz
```

## Como funciona

- `docker-compose.yml` monta `./scripts` dentro del contenedor como `/scripts`.
- El workflow ejecuta `sh /scripts/backup-mysql-to-pg.sh`.
- La imagen personalizada copia `mysqldump` desde una etapa Alpine para evitar instalar paquetes dentro de `n8nio/n8n:latest`.
- La imagen tambien copia los plugins del cliente MariaDB para soportar autenticacion `caching_sha2_password`.
- En n8n 2.x, `Execute Command` viene bloqueado por defecto. Este proyecto lo habilita con `NODES_EXCLUDE=["n8n-nodes-base.localFileTrigger"]`.
- Para proxies MySQL con certificados autofirmados, el script usa SSL pero desactiva la verificacion del certificado con `MYSQL_SSL_VERIFY_SERVER_CERT=false`.

## Restaurar un backup

```bash
gunzip -c backups/ch_polarizados_20260323_020000.sql.gz | \
  mysql -h HOST -P PORT -u root -p railway
```

## Ver logs

```bash
docker logs n8n-ch-polarizados -f
```

## Validar un backup

```bash
sh scripts/validate-backup.sh backups/ch_polarizados_20260323_172456.sql.gz
```

El script verifica que:
- el `.gz` no este corrupto
- el contenido no este vacio
- el archivo parezca un dump SQL real

## Notificaciones opcionales

En el nodo `Success` del workflow puedes conectar Telegram, Slack o email y enviar `{{ $json.file }} ({{ $json.size }})`.
