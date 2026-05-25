#!/bin/bash
# ==============================================================================
# Script: 12-desplegar-zabbix.sh
# Proyecto: JASOC (Infraestructura MSSP)
# Descripción: Despliegue desatendido de Zabbix 7.0 LTS + PostgreSQL + Nginx
# Host: JASOC-ZABBIX
# IP: 192.168.30.6 (VLAN 30 - GESTIÓN)
# ==============================================================================

# Detener el script si hay algún fallo crítico
set -e

# Modo no interactivo para que APT no haga preguntas
export DEBIAN_FRONTEND=noninteractive

echo "[*] 1. Configurando Locales (Inglés y Español) para Zabbix..."
apt update -y && apt install -y locales
sed -i 's/^# *\(en_US.UTF-8\)/\1/' /etc/locale.gen
sed -i 's/^# *\(es_ES.UTF-8\)/\1/' /etc/locale.gen
locale-gen

echo "[*] 2. Descargando repositorios oficiales de Zabbix 7.0..."
wget -q https://repo.zabbix.com/zabbix/7.0/debian/pool/main/z/zabbix-release/zabbix-release_7.0-2+debian12_all.deb
dpkg -i zabbix-release_7.0-2+debian12_all.deb
apt update -y

echo "[*] 3. Instalando Zabbix Server, Frontend, Nginx y PostgreSQL..."
apt install -y zabbix-server-pgsql zabbix-frontend-php php8.2-pgsql zabbix-nginx-conf zabbix-sql-scripts zabbix-agent postgresql

echo "[*] 4. Reseteando y preparando la base de datos PostgreSQL..."
# Se elimina si ya existía para garantizar idempotencia
sudo -u postgres dropdb --if-exists zabbix
sudo -u postgres dropuser --if-exists zabbix

# Creación de usuario y base de datos
sudo -u postgres psql -c "CREATE USER zabbix WITH PASSWORD '*******';"
sudo -u postgres createdb -O zabbix zabbix

echo "[*] 5. Importando esquema oficial de Zabbix (Esto tarda 1 minuto)..."
zcat /usr/share/zabbix-sql-scripts/postgresql/server.sql.gz | sudo -u zabbix psql zabbix

echo "[*] 6. Inyectando credenciales en la configuración de Zabbix Server..."
sed -i 's/# DBPassword=/DBPassword=**********/' /etc/zabbix/zabbix_server.conf

echo "[*] 7. Configurando Nginx para la IP 192.168.30.6 (Puerto 8080)..."
# Purga del sitio por defecto que bloquea el puerto 80
rm -f /etc/nginx/sites-enabled/default

# Reemplazo con expresiones regulares (ignora múltiples espacios/tabulaciones)
sed -i -E 's/^[[:space:]]*#[[:space:]]*listen[[:space:]]+8080;/        listen          8080;/' /etc/zabbix/nginx.conf
sed -i -E 's/^[[:space:]]*#[[:space:]]*server_name[[:space:]]+example\.com;/        server_name     192.168.30.6;/' /etc/zabbix/nginx.conf

echo "[*] 8. Reiniciando y habilitando todos los servicios en el arranque..."
systemctl restart zabbix-server zabbix-agent nginx php8.2-fpm
systemctl enable zabbix-server zabbix-agent nginx php8.2-fpm

echo "========================================================================="
echo "[V] DESPLIEGUE FINALIZADO CON ÉXITO."
echo "    Accede al panel web en: http://192.168.30.6:8080"
echo "    Todo el entorno está listo para el check de pre-requisitos de Zabbix."
echo "========================================================================="
