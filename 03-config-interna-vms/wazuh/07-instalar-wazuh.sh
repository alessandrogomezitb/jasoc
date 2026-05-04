#!/bin/bash
#
# Script: 07-instalar-wazuh.sh
# Descripción: Instala Wazuh en modo all-in-one dentro de la VM ya creada.
# Uso: sudo bash 07-instalar-wazuh.sh
#

set -euo pipefail

WAZUH_INSTALL_URL="https://packages.wazuh.com/4.14/wazuh-install.sh"
INSTALLER="wazuh-install.sh"
LOG_FILE="/root/wazuh-install-$(date +%F-%H%M%S).log"

echo "=========================================="
echo " Instalacion de Wazuh all-in-one"
echo "=========================================="

# 1. Comprobar privilegios
if [ "${EUID}" -ne 0 ]; then
  echo "ERROR: Este script debe ejecutarse como root."
  exit 1
fi

# 2. Comprobar conectividad
echo "[1/8] Comprobando conectividad..."
ping -c 2 8.8.8.8 >/dev/null 2>&1 || {
  echo "ERROR: No hay salida a Internet."
  exit 1
}

# 3. Actualizar sistema e instalar utilidades minimas
echo "[2/8] Actualizando paquetes base..."
apt update
apt install -y curl tar

# 4. Ajustar hostname si esta sin definir o en cloud-init genérico
echo "[3/8] Configurando hostname..."
CURRENT_HOSTNAME="$(hostnamectl --static 2>/dev/null || hostname)"
if [ -z "${CURRENT_HOSTNAME}" ] || [ "${CURRENT_HOSTNAME}" = "localhost" ]; then
  hostnamectl set-hostname wazuh
fi

# 5. Descargar instalador oficial
echo "[4/8] Descargando instalador oficial de Wazuh..."
curl -sO "${WAZUH_INSTALL_URL}"

if [ ! -f "${INSTALLER}" ]; then
  echo "ERROR: No se ha podido descargar ${INSTALLER}"
  exit 1
fi

chmod +x "${INSTALLER}"

# 6. Ejecutar instalacion all-in-one
echo "[5/8] Instalando Wazuh. Esto puede tardar varios minutos..."
bash "./${INSTALLER}" -a | tee "${LOG_FILE}"

# 7. Mostrar credenciales si el asistente generó el bundle
echo "[6/8] Buscando credenciales..."
if [ -f "wazuh-install-files.tar" ]; then
  echo "----- Credenciales generadas por Wazuh -----"
  tar -O -xvf wazuh-install-files.tar wazuh-install-files/wazuh-passwords.txt 2>/dev/null || true
  echo "-------------------------------------------"
else
  echo "No se encontró wazuh-install-files.tar en el directorio actual."
fi

# 8. Desactivar repo de Wazuh para evitar upgrades accidentales
echo "[7/8] Desactivando repositorio de Wazuh..."
if [ -f /etc/apt/sources.list.d/wazuh.list ]; then
  sed -i 's/^deb /#deb /' /etc/apt/sources.list.d/wazuh.list
  apt update
fi

# 9. Mostrar resumen final
echo "[8/8] Resumen final..."
IP_PRINCIPAL="$(hostname -I 2>/dev/null | awk '{print $1}')"

echo
echo "=========================================="
echo " Wazuh instalado"
echo "=========================================="
echo "URL: https://${IP_PRINCIPAL}"
echo "Usuario: admin"
echo "Revisa el log: ${LOG_FILE}"
echo
echo "Servicios instalados:"
systemctl --no-pager --type=service --state=running | grep -E 'wazuh|filebeat|opensearch|dashboard' || true
echo
echo "Si el navegador avisa del certificado, es normal en la primera entrada."
