#!/bin/bash
#
# Script: 11-instalar-bbdd.sh
# Descripcion: Configura la VM JASOC-BBDD como servidor PostgreSQL
#              para Nextcloud en VLAN 20.
# Uso: sudo bash 11-instalar-bbdd.sh
#

set -euo pipefail

# =========================
# VARIABLES JASOC
# =========================
HOSTNAME_DB="JASOC-BBDD"

BBDD_IP="192.168.20.2"
DMZ_NET="192.168.10.0/24"

DB_NAME="nextcloud_db"
DB_USER="nextcloud_user"

WAZUH_MANAGER="192.168.30.5"
ZABBIX_SERVER="192.168.30.12"

LOG_FILE="/root/bbdd-install-$(date +%F-%H%M%S).log"

echo "=========================================="
echo " Instalacion BBDD PostgreSQL - JASOC"
echo "=========================================="

# =========================
# VALIDACIONES
# =========================
if [ "${EUID}" -ne 0 ]; then
  echo "ERROR: Ejecuta este script como root."
  exit 1
fi

echo "[1/9] Configurando hostname..."
hostnamectl set-hostname "${HOSTNAME_DB}"

echo "[2/9] Comprobando conectividad basica..."
ping -c 2 192.168.20.1 >/dev/null 2>&1 || {
  echo "ERROR: No hay conectividad con el gateway VLAN 20."
  exit 1
}

ping -c 2 "${WAZUH_MANAGER}" >/dev/null 2>&1 || {
  echo "AVISO: No responde Wazuh Manager ${WAZUH_MANAGER}. Continuo igualmente."
}

# =========================
# PASSWORD DB
# =========================
echo "[3/9] Solicitando password segura para PostgreSQL..."
read -rsp "Introduce password para ${DB_USER}: " DB_PASS
echo

if [ -z "${DB_PASS}" ]; then
  echo "ERROR: La password no puede estar vacia."
  exit 1
fi

# =========================
# PAQUETES BASE
# =========================
echo "[4/9] Actualizando sistema e instalando paquetes..."
apt update | tee -a "${LOG_FILE}"

apt install -y \
  curl \
  wget \
  gnupg2 \
  lsb-release \
  ca-certificates \
  netcat-openbsd \
  postgresql \
  postgresql-contrib \
  zabbix-agent | tee -a "${LOG_FILE}"

# =========================
# POSTGRESQL
# =========================
echo "[5/9] Configurando PostgreSQL..."

PG_VERSION="$(ls /etc/postgresql | head -n 1)"
PG_CONF="/etc/postgresql/${PG_VERSION}/main/postgresql.conf"
PG_HBA="/etc/postgresql/${PG_VERSION}/main/pg_hba.conf"

if [ ! -f "${PG_CONF}" ] || [ ! -f "${PG_HBA}" ]; then
  echo "ERROR: No se han encontrado ficheros de PostgreSQL."
  exit 1
fi

cp "${PG_CONF}" "${PG_CONF}.bak.$(date +%F-%H%M%S)"
cp "${PG_HBA}" "${PG_HBA}.bak.$(date +%F-%H%M%S)"

sed -i "s/^#*listen_addresses.*/listen_addresses = '${BBDD_IP}'/" "${PG_CONF}"

grep -q "^password_encryption" "${PG_CONF}" \
  && sed -i "s/^password_encryption.*/password_encryption = scram-sha-256/" "${PG_CONF}" \
  || echo "password_encryption = scram-sha-256" >> "${PG_CONF}"

grep -q "^log_connections" "${PG_CONF}" \
  && sed -i "s/^log_connections.*/log_connections = on/" "${PG_CONF}" \
  || echo "log_connections = on" >> "${PG_CONF}"

grep -q "^log_disconnections" "${PG_CONF}" \
  && sed -i "s/^log_disconnections.*/log_disconnections = on/" "${PG_CONF}" \
  || echo "log_disconnections = on" >> "${PG_CONF}"

grep -q "JASOC_NEXTCLOUD_ACCESS" "${PG_HBA}" || cat <<EOF >> "${PG_HBA}"

# JASOC_NEXTCLOUD_ACCESS
# Solo Nextcloud/DMZ puede conectarse a la BBDD
host    ${DB_NAME}    ${DB_USER}    ${DMZ_NET}    scram-sha-256
EOF

# =========================
# DB Y USUARIO
# =========================
echo "[6/9] Creando usuario y base de datos Nextcloud..."

sudo -u postgres psql <<EOF
DO
\$do\$
BEGIN
   IF NOT EXISTS (
      SELECT FROM pg_catalog.pg_roles WHERE rolname = '${DB_USER}'
   ) THEN
      CREATE ROLE ${DB_USER} LOGIN PASSWORD '${DB_PASS}';
   ELSE
      ALTER ROLE ${DB_USER} WITH PASSWORD '${DB_PASS}';
   END IF;
END
\$do\$;

SELECT 'CREATE DATABASE ${DB_NAME} OWNER ${DB_USER}'
WHERE NOT EXISTS (
   SELECT FROM pg_database WHERE datname = '${DB_NAME}'
)\\gexec

GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};
EOF

systemctl enable postgresql
systemctl restart postgresql

# =========================
# ZABBIX AGENT
# =========================
echo "[7/9] Configurando Zabbix Agent..."

ZBX_CONF="/etc/zabbix/zabbix_agentd.conf"

if [ -f "${ZBX_CONF}" ]; then
  cp "${ZBX_CONF}" "${ZBX_CONF}.bak.$(date +%F-%H%M%S)"

  sed -i "s/^Server=.*/Server=${ZABBIX_SERVER}/" "${ZBX_CONF}"
  sed -i "s/^ServerActive=.*/ServerActive=${ZABBIX_SERVER}/" "${ZBX_CONF}"
  sed -i "s/^Hostname=.*/Hostname=${HOSTNAME_DB}/" "${ZBX_CONF}"

  systemctl enable zabbix-agent
  systemctl restart zabbix-agent
else
  echo "AVISO: No se encontro configuracion de Zabbix Agent."
fi

# =========================
# WAZUH AGENT
# =========================
echo "[8/9] Preparando configuracion de Wazuh Agent..."

if systemctl list-unit-files | grep -q wazuh-agent; then
  echo "Wazuh Agent ya esta instalado. Ajustando manager..."

  WAZUH_CONF="/var/ossec/etc/ossec.conf"

  if [ -f "${WAZUH_CONF}" ]; then
    cp "${WAZUH_CONF}" "${WAZUH_CONF}.bak.$(date +%F-%H%M%S)"
    sed -i "s|<address>.*</address>|<address>${WAZUH_MANAGER}</address>|" "${WAZUH_CONF}"
    systemctl enable wazuh-agent
    systemctl restart wazuh-agent
  fi
else
  echo "AVISO: Wazuh Agent no esta instalado desde este script."
  echo "      No lo reinstalo para no romper el agente ya registrado."
fi

# =========================
# HARDENING BASICO SIN FIREWALL LOCAL
# =========================
echo "[9/9] Aplicando hardening basico del sistema..."

cat <<EOF > /etc/sysctl.d/99-jasoc-bbdd-hardening.conf
# JASOC - Hardening basico servidor BBDD
net.ipv4.ip_forward=0
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.send_redirects=0
net.ipv4.conf.all.accept_source_route=0
net.ipv4.conf.default.accept_source_route=0
EOF

sysctl --system >/dev/null

# =========================
# VALIDACIONES FINALES
# =========================
echo
echo "Validaciones finales..."
systemctl --no-pager status postgresql | head -n 12 || true
systemctl --no-pager status zabbix-agent | head -n 12 || true

ss -tulpen | grep 5432 || {
  echo "AVISO: PostgreSQL no parece estar escuchando en 5432."
}

echo
echo "=========================================="
echo " BBDD JASOC configurada correctamente"
echo "=========================================="
echo "Hostname:        ${HOSTNAME_DB}"
echo "IP BBDD:         ${BBDD_IP}"
echo "Base de datos:   ${DB_NAME}"
echo "Usuario DB:      ${DB_USER}"
echo "Acceso permitido desde: ${DMZ_NET}"
echo "Wazuh Manager:   ${WAZUH_MANAGER}"
echo "Zabbix Server:   ${ZABBIX_SERVER}"
echo "Firewall local:  No configurado, gestion centralizada en pfSense"
echo "Log instalacion: ${LOG_FILE}"
echo "=========================================="
echo
echo "Prueba desde JASOC-WEB:"
echo "nc -zv ${BBDD_IP} 5432"
echo
echo "Prueba local:"
echo "psql -h ${BBDD_IP} -U ${DB_USER} -d ${DB_NAME}"
