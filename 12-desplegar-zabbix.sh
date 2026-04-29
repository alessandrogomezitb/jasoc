#!/bin/bash
# ==========================================
# AUTO-DEPLOY ZABBIX SERVER (Ganado, no mascotas)
# ==========================================
# Host: JASOC-ZABBIX (192.168.30.6)
# VLAN 30 - Gestión
# ==========================================

echo "[*] 1. Descargando repositorios oficiales de Zabbix 7.0 para Debian 12..."
wget https://repo.zabbix.com/zabbix/7.0/debian/pool/main/z/zabbix-release/zabbix-release_7.0-2+debian12_all.deb
dpkg -i zabbix-release_7.0-2+debian12_all.deb
apt update -y

echo "[*] 2. Instalando Zabbix Server, Frontend, Nginx y PostgreSQL..."
apt install -y zabbix-server-pgsql zabbix-frontend-php php8.2-pgsql zabbix-nginx-conf zabbix-sql-scripts zabbix-agent postgresql

echo "[*] 3. Creando usuario y base de datos PostgreSQL en modo silencioso..."
sudo -u postgres psql -c "CREATE USER zabbix WITH PASSWORD 'JasocZabbix2026!';"
sudo -u postgres createdb -O zabbix zabbix

echo "[*] 4. Importando esquema inicial de la base de datos (Esto puede tardar 1 minuto)..."
zcat /usr/share/zabbix-sql-scripts/postgresql/server.sql.gz | sudo -u zabbix psql zabbix

echo "[*] 5. Inyectando credenciales en la configuración del Server..."
sed -i 's/# DBPassword=/DBPassword=JasocZabbix2026!/' /etc/zabbix/zabbix_server.conf

echo "[*] 6. Configurando Nginx para la IP 192.168.30.6..."
sed -i 's/# listen 8080;/listen 8080;/' /etc/zabbix/nginx.conf
sed -i 's/# server_name example.com;/server_name 192.168.30.6;/' /etc/zabbix/nginx.conf

echo "[*] 7. Reiniciando y habilitando demonios..."
systemctl restart zabbix-server zabbix-agent nginx php8.2-fpm
systemctl enable zabbix-server zabbix-agent nginx php8.2-fpm

echo "[V] ZABBIX DESPLEGADO CON ÉXITO EN 192.168.30.6:8080"
