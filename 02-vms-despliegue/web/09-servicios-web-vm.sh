#!/bin/bash
#
# Script: 09-servicios-web-vm.sh
# Descripción: Despliegue de la VM de Servicios Web para JASOC
#              en la VLAN 10 (DMZ), a partir de la plantilla cloud-init.
#

set -euo pipefail

# =========================
# VARIABLES DEL DESPLIEGUE
# =========================
VMID=220
VM_NAME="JASOC-WEB"
TEMPLATE_ID=9000      # ID de tu plantilla Debian 12

BRIDGE="vmbr1"        # Bridge donde están las VLANs
VLAN_TAG=10           # VLAN 10 = DMZ

RAM=4096
CORES=2
DISK_SIZE="40G"

CI_USER="****"
CI_PASSWORD="**********"  # Cambiadla en el primer login
SSH_KEY="/root/.ssh/id_rsa.pub"

echo "========================================"
echo " Despliegue VM Servicios Web (DMZ)"
echo "========================================"

# 1. Validaciones
echo "[1/4] Validando entorno..."
if qm status "${VMID}" >/dev/null 2>&1; then
    echo "ERROR: La VM ${VMID} ya existe."
    exit 1
fi

# 2. Clonar Plantilla
echo "[2/4] Clonando plantilla ${TEMPLATE_ID}..."
qm clone "${TEMPLATE_ID}" "${VMID}" --name "${VM_NAME}" --full true

# 3. Configurar Recursos y Red
echo "[3/4] Asignando recursos y VLAN ${VLAN_TAG}..."
qm set "${VMID}" --cores "${CORES}" --memory "${RAM}"
qm set "${VMID}" --net0 virtio,bridge="${BRIDGE}",tag="${VLAN_TAG}"
qm resize "${VMID}" scsi0 "${DISK_SIZE}"

# 4. Configurar Cloud-Init
echo "[4/4] Aplicando configuración Cloud-Init..."
qm set "${VMID}" --ciuser "${CI_USER}"
qm set "${VMID}" --cipassword "${CI_PASSWORD}"
qm set "${VMID}" --ipconfig0 ip=dhcp
qm set "${VMID}" --onboot 1
qm set "${VMID}" --agent 1

if [ -f "${SSH_KEY}" ]; then
    qm set "${VMID}" --sshkeys "${SSH_KEY}"
fi

echo "========================================"
echo " VM WEB DESPLEGADA CORRECTAMENTE"
echo " ID: ${VMID} | VLAN: ${VLAN_TAG} (DMZ)"
echo "========================================"
