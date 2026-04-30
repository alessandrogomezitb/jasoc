#!/bin/bash
# ==============================================================================
# Script: 13b-desplegar-agente-zabbix-PROXMOX.sh
# Proyecto: JASOC (Infraestructura MSSP)
# Descripción: Instalación nativa para Proxmox 8 (Debian 13 Trixie) - EXTERNO
# ==============================================================================

set -e
export DEBIAN_FRONTEND=noninteractive

# Apuntamos al pfSense
ZABBIX_SERVER="172.20.17.206"
HOST_NAME=$(hostname)

echo "[*] Instalando el Agente Zabbix nativo de Debian 13..."
apt update -y
apt install -y zabbix-agent

echo "[*] Configurando el Agente para apuntar al firewall ($ZABBIX_SERVER)..."
cp /etc/zabbix/zabbix_agentd.conf /etc/zabbix/zabbix_agentd.conf.bak

sed -i "s/^Server=127.0.0.1/Server=$ZABBIX_SERVER/" /etc/zabbix/zabbix_agentd.conf
sed -i "s/^ServerActive=127.0.0.1/ServerActive=$ZABBIX_SERVER/" /etc/zabbix/zabbix_agentd.conf
sed -i "s/^Hostname=Zabbix server/Hostname=$HOST_NAME/" /etc/zabbix/zabbix_agentd.conf

echo "[*] Reiniciando y habilitando el servicio..."
systemctl restart zabbix-agent
systemctl enable zabbix-agent

echo "========================================================================="
echo "[V] AGENTE PROXMOX DESPLEGADO CON ÉXITO EN: $HOST_NAME"
echo "========================================================================="
