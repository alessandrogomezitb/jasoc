#!/bin/bash
# ==============================================================================
# Script: 16-desplegar-nextcloud.sh
# Proyecto: JASOC (Infraestructura MSSP)
# Descripción: Crea el docker-compose y despliega Nextcloud conectado a la DB
# ==============================================================================

set -e

DIR_PROYECTO="/opt/jasoc-web"

echo "[*] 1. Generando archivo docker-compose.yml..."
cat << 'EOF' > "$DIR_PROYECTO/docker-compose.yml"
services:
  nextcloud:
    image: nextcloud:latest
    container_name: nextcloud_app
    restart: always
    ports:
      - "80:80"
    environment:
      - POSTGRES_HOST=192.168.20.2
      - POSTGRES_DB=*******
      - POSTGRES_USER=********
      - POSTGRES_PASSWORD=**************
    volumes:
      - /opt/jasoc-web/nextcloud:/var/www/html
EOF

echo "[*] 2. Desplegando el contenedor de Nextcloud..."
cd "$DIR_PROYECTO"
docker compose up -d

echo "========================================================================="
echo "[V] NEXTCLOUD DESPLEGADO CON ÉXITO."
echo "Accede a: http://192.168.10.2"
echo "========================================================================="
