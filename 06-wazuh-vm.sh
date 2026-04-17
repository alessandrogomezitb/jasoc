#!/bin/bash
#
# Script: 06-wazuh-vm.sh
# Descripción: Despliegue de la VM para el servidor Wazuh a partir de la plantilla cloud-init

# --- VARIABLES ---
VMID=200
VM_NAME="JASOC-WAZUH"
TEMPLATE_ID=9000

RAM=8192
CORES=4
DISK_STORAGE="local-lvm"
BRIDGE="vmbr1"   # VLAN trunk → luego se asignará VLAN 30 (GESTION)

echo "Desplegando servidor Wazuh..."

# --- VALIDACIONES ---
if qm status $VMID >/dev/null 2>&1; then
    echo "ERROR: La VM $VMID ya existe."
    exit 1
fi

if ! qm status $TEMPLATE_ID >/dev/null 2>&1; then
    echo "ERROR: No existe la plantilla $TEMPLATE_ID."
    exit 1
fi

# --- CLONAR TEMPLATE ---
echo "Clonando plantilla $TEMPLATE_ID..."
qm clone $TEMPLATE_ID $VMID --name $VM_NAME --full true

# --- CONFIGURAR RECURSOS ---
echo "Asignando recursos..."
qm set $VMID --memory $RAM --cores $CORES

# --- RED (IMPORTANTE) ---
# Conectado a vmbr1 (trunk), luego usaremos VLAN 30 (GESTION)
qm set $VMID --net0 virtio,bridge=$BRIDGE,tag=30

# --- DISCO (opcional ampliar) ---
qm resize $VMID scsi0 100G

# --- CLOUD-INIT ---
echo "Configurando Cloud-Init..."

qm set $VMID --ipconfig0 ip=dhcp
qm set $VMID --ciuser wazuhadmin
qm set $VMID --cipassword 'Wazuh123!'
qm set $VMID --sshkeys ~/.ssh/id_rsa.pub

# --- ARRANQUE AUTOMATICO ---
qm set $VMID --onboot 1

# --- CONSOLA ---
qm set $VMID --serial0 socket --vga serial0

echo "---------------------------------------"
echo "VM WAZUH desplegada correctamente"
echo "ID: $VMID"
echo "Nombre: $VM_NAME"
echo "VLAN: GESTION (30)"
echo "IP: DHCP (pfSense)"
echo "---------------------------------------"
echo "Siguiente paso: instalar Wazuh dentro de la VM"
