#!/bin/bash
# Volcado de seguridad diario de PostgreSQL
FECHA=$(date +"%Y-%m-%d")
DESTINO="/var/backups/jasoc-bbdd"

mkdir -p $DESTINO
PGPASSWORD="Jasoc_Nextcloud_2026" pg_dump -h 127.0.0.1 -U nextcloud_user nextcloud_db | gzip > $DESTINO/db_backup_$FECHA.sql.gz

# Borrar copias con más de 7 días de antigüedad
find $DESTINO -type f -name "*.sql.gz" -mtime +7 -delete
