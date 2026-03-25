#!/bin/sh
set -e

# Railway monta volúmenes como root — corregir permisos antes de iniciar n8n
mkdir -p /home/node/.n8n
chown -R node:node /home/node/.n8n

exec su-exec node n8n "$@"
