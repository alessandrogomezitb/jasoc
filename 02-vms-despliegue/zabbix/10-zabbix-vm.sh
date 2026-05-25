#!/bin/bash
#
# Script: 10-zabbix-vm.sh
# Descripcion: Despliegue de la VM para monitorización Zabbix en la VLAN 30 (GESTION)
#              clonando la plantilla Debian cloud-init.
#

set -euo pipefail

# =========================
# VARIABLES
# =========================
VMID=230
VM_NAME="JASOC-ZABBIX"
TEMPLATE_ID=9000

BRIDGE="vmbr1"
VLAN_TAG=30

RAM=4096
CORES=2
DISK_SIZE="40G"

CI_USER="*****"
CI_PASSWORD="*********"

# =========================
# DESPLIEGUE
# =========================
echo "========================================"
echo " Despliegue VM Zabbix JASOC"
echo "========================================"

# Validar que no exista la máquina
if qm status "${VMID}" >/dev/null 2>&1; then
    echo "ERROR: La VM ${VMID} ya existe."
    exit 1
fi

echo "[1/4] Clonando plantilla ${TEMPLATE_ID}..."
qm clone "${TEMPLATE_ID}" "${VMID}" --name "${VM_NAME}" --full true

echo "[2/4] Asignando recursos (RAM, CPU, Disco)..."
qm set "${VMID}" --memory "${RAM}" --cores "${CORES}"
qm resize "${VMID}" scsi0 "${DISK_SIZE}"

echo "[3/4] Configurando Red (VLAN ${VLAN_TAG} - GESTION)..."
qm set "${VMID}" --net0 virtio,bridge="${BRIDGE}",tag="${VLAN_TAG}"

echo "[4/4] Configurando Cloud-Init..."
qm set "${VMID}" --ciuser "${CI_USER}"
qm set "${VMID}" --cipassword "${CI_PASSWORD}"
qm set "${VMID}" --ipconfig0 ip=dhcp
qm set "${VMID}" --onboot 1
qm set "${VMID}" --agent 1

echo "========================================"
echo " VM ZABBIX desplegada correctamente."
echo " ID: ${VMID} | VLAN: ${VLAN_TAG}"
echo "========================================"
