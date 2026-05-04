#!/bin/bash
#
# Script: 08-BBDD-JASOC-v2.sh
# Descripcion: Crea la VM de base de datos en la VLAN 20 (DATOS)
#              clonando la plantilla Debian cloud-init y recreando
#              la interfaz de red de forma explicita.
#

set -euo pipefail

# =========================
# VARIABLES
# =========================
VMID=210
VM_NAME="JASOC-BBDD"
TEMPLATE_ID=9000

BRIDGE="vmbr1"
VLAN_TAG=20

RAM=4096
CORES=2
DISK_SIZE="60G"

CI_USER="dbadmin"
CI_PASSWORD="CambiaEstaPassword123!"

SSH_KEY="/root/.ssh/id_rsa.pub"

echo "========================================"
echo " Despliegue VM BBDD JASOC v2"
echo "========================================"

# =========================
# VALIDACIONES
# =========================
echo "[1/9] Validando entorno..."

if qm status "${VMID}" >/dev/null 2>&1; then
    echo "ERROR: La VM ${VMID} ya existe."
    echo "Borrala primero con: qm stop ${VMID} && qm destroy ${VMID} --purge 1"
    exit 1
fi

if ! qm status "${TEMPLATE_ID}" >/dev/null 2>&1; then
    echo "ERROR: No existe la plantilla ${TEMPLATE_ID}."
    exit 1
fi

if ! grep -q "^auto ${BRIDGE}\|^iface ${BRIDGE} " /etc/network/interfaces; then
    echo "ERROR: El bridge ${BRIDGE} no existe en /etc/network/interfaces."
    exit 1
fi

if ! grep -A5 "iface ${BRIDGE}" /etc/network/interfaces | grep -q "bridge-vlan-aware yes"; then
    echo "ERROR: ${BRIDGE} no tiene 'bridge-vlan-aware yes'."
    exit 1
fi

# =========================
# CLONADO
# =========================
echo "[2/9] Clonando plantilla ${TEMPLATE_ID}..."
qm clone "${TEMPLATE_ID}" "${VMID}" --name "${VM_NAME}" --full true

# =========================
# RECURSOS
# =========================
echo "[3/9] Asignando CPU, RAM y disco..."
qm set "${VMID}" --memory "${RAM}" --cores "${CORES}"
qm resize "${VMID}" scsi0 "${DISK_SIZE}"

# =========================
# RED
# =========================
echo "[4/9] Recreando interfaz de red de forma explicita..."
qm set "${VMID}" --delete net0 || true
qm set "${VMID}" --net0 "virtio,bridge=${BRIDGE},tag=${VLAN_TAG}"

# =========================
# CLOUD-INIT
# =========================
echo "[5/9] Configurando Cloud-Init..."
qm set "${VMID}" --ciuser "${CI_USER}"
qm set "${VMID}" --cipassword "${CI_PASSWORD}"
qm set "${VMID}" --ipconfig0 ip=dhcp

if [ -f "${SSH_KEY}" ]; then
    qm set "${VMID}" --sshkeys "${SSH_KEY}"
    echo "  -> SSH key añadida desde ${SSH_KEY}"
else
    echo "  -> No se encontro ${SSH_KEY}, se omite."
fi

# =========================
# ARRANQUE / AGENTE / CONSOLA
# =========================
echo "[6/9] Configurando arranque y consola..."
qm set "${VMID}" --onboot 1
qm set "${VMID}" --agent 1
qm set "${VMID}" --serial0 socket --vga serial0

# =========================
# ORDEN DE ARRANQUE
# =========================
echo "[7/9] Ajustando orden de arranque..."
qm set "${VMID}" --boot "order=scsi0"

# =========================
# MOSTRAR CONFIG
# =========================
echo "[8/9] Configuracion final:"
qm config "${VMID}"

# =========================
# FIN
# =========================
echo "[9/9] VM creada correctamente."
echo
echo "========================================"
echo " VM BBDD desplegada"
echo "========================================"
echo "ID:        ${VMID}"
echo "Nombre:    ${VM_NAME}"
echo "Bridge:    ${BRIDGE}"
echo "VLAN:      ${VLAN_TAG} (DATOS)"
echo "IP:        DHCP por pfSense"
echo "Usuario:   ${CI_USER}"
echo "========================================"
echo
echo "Siguientes pasos:"
echo "1) Arrancar la VM: qm start ${VMID}"
echo "2) Comprobar que recibe IP de 192.168.20.0/24"
echo "3) Probar:"
echo "   ping 192.168.20.1"
echo "   ping 8.8.8.8"
