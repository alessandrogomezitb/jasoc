#!/bin/bash
# ==============================================================================
# Script: 15-preparar-bbdd-nextcloud.sh
# Proyecto: JASOC (Infraestructura MSSP)
# Descripción: Instala PostgreSQL y configura la DB para la DMZ (JASOC-WEB)
# ==============================================================================

set -e
export DEBIAN_FRONTEND=noninteractive

# Variables de configuración
IP_WEB="192.168.10.2"
DB_NAME="nextcloud_db"
DB_USER="nextcloud_user"
# Contraseña segura sin caracteres especiales de bash
DB_PASS="**********" 

echo "[*] 1. Instalando PostgreSQL..."
apt update -y
apt install -y postgresql postgresql-contrib

echo "[*] 2. Localizando archivos de configuración..."
PG_CONF=$(find /etc/postgresql/ -name postgresql.conf)
PG_HBA=$(find /etc/postgresql/ -name pg_hba.conf)

echo "[*] 3. Configurando PostgreSQL para escuchar en la red interna..."
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" "$PG_CONF"

echo "[*] 4. Permitiendo conexión ÚNICAMENTE desde JASOC-WEB ($IP_WEB)..."
# Verificamos si la regla ya existe para no duplicarla
if ! grep -q "$IP_WEB" "$PG_HBA"; then
    echo "host    $DB_NAME    $DB_USER    $IP_WEB/32    scram-sha-256" >> "$PG_HBA"
fi

echo "[*] 5. Reiniciando el servicio para aplicar configuración de red..."
systemctl restart postgresql
systemctl enable postgresql

echo "[*] 6. Creando Base de Datos y Usuario para Nextcloud de forma segura..."
# Usamos un bloque para evitar errores si ya existen
sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'" | grep -q 1 || sudo -u postgres psql -c "CREATE USER $DB_USER WITH ENCRYPTED PASSWORD '$DB_PASS';"
sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1 || sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"
sudo -u postgres psql -d $DB_NAME -c "GRANT ALL ON SCHEMA public TO $DB_USER;"

echo "========================================================================="
echo "[V] JASOC-BBDD PREPARADA CON ÉXITO."
echo "- Base de datos: $DB_NAME"
echo "- Usuario: $DB_USER"
echo "- Acceso permitido SOLO desde: $IP_WEB"
echo "========================================================================="
