#!/bin/bash
# ==============================================================================
# Script: 13c-desplegar-agente-zabbix-INTERNO.sh
# Proyecto: JASOC (Infraestructura MSSP)
# Descripción: Instalación para máquinas DENTRO del pfSense (Debian 12)
# ==============================================================================

set -e
export DEBIAN_FRONTEND=noninteractive

# OJO: APUNTAMOS DIRECTAMENTE AL BÚNKER (Red interna)
ZABBIX_SERVER="192.168.30.6"
HOST_NAME=$(hostname)

echo "[*] 1. Descargando repositorio de Zabbix 7.0 (Debian 12)..."
wget -q https://repo.zabbix.com/zabbix/7.0/debian/pool/main/z/zabbix-release/zabbix-release_7.0-2+debian12_all.deb
dpkg -i zabbix-release_7.0-2+debian12_all.deb
apt update -y

echo "[*] 2. Instalando el Agente Zabbix..."
apt install -y zabbix-agent

echo "[*] 3. Configurando el Agente para apuntar al búnker ($ZABBIX_SERVER)..."
cp /etc/zabbix/zabbix_agentd.conf /etc/zabbix/zabbix_agentd.conf.bak

sed -i "s/^Server=127.0.0.1/Server=$ZABBIX_SERVER/" /etc/zabbix/zabbix_agentd.conf
sed -i "s/^ServerActive=127.0.0.1/ServerActive=$ZABBIX_SERVER/" /etc/zabbix/zabbix_agentd.conf
sed -i "s/^Hostname=Zabbix server/Hostname=$HOST_NAME/" /etc/zabbix/zabbix_agentd.conf

echo "[*] 4. Reiniciando y habilitando el servicio..."
systemctl restart zabbix-agent
systemctl enable zabbix-agent

echo "========================================================================="
echo "[V] AGENTE INTERNO DESPLEGADO CON ÉXITO EN: $HOST_NAME"
echo "========================================================================="
