#!/bin/bash
# Copia de seguridad diaria de ficheros
FECHA=$(date +"%Y-%m-%d")
DESTINO="/var/backups/jasoc-web"

mkdir -p $DESTINO
tar -czf $DESTINO/web_backup_$FECHA.tar.gz -C /opt jasoc-web

# Borrar copias con más de 7 días de antigüedad
find $DESTINO -type f -name "*.tar.gz" -mtime +7 -delete
