#!/bin/bash
# 
# Script: 05-pFSense-JASALUD.sh
# Autores: Jostin y Alessandro
# Descripcion: Despliegue automatizado de la VM base para el firewall pfSense.
#              Configura 2 interfaces: WAN (salida) y LAN (Trunk para las 4 VLANs).

# --- VARIABLES DEL DESPLIEGUE ---
VMID=100
VM_NAME="JASOC-pfSense"
RAM=2048
CORES=2
DISK_SIZE="32"
DISK_STORAGE="local-lvm"
ISO_STORAGE="local"
ISO_NAME="pfSense.iso"

echo "Iniciando creacion de la VM para pfSense ($VM_NAME - ID: $VMID)..."

# 1. Crear la maquina virtual
qm create $VMID --name $VM_NAME --ostype other --memory $RAM --cores $CORES --numa 0

# 2. Configurar el hardware de red (El cableado)
echo "Conectando las interfaces de red WAN y LAN..."
qm set $VMID --net0 virtio,bridge=vmbr0
qm set $VMID --net1 virtio,bridge=vmbr1

# 3. Configurar el almacenamiento (Corregido a numero entero)
echo "Creando el disco principal de ${DISK_SIZE}GB..."
qm set $VMID --scsihw virtio-scsi-pci --scsi0 $DISK_STORAGE:$DISK_SIZE

# 4. Montar la ISO de instalacion
echo "Montando la ISO $ISO_NAME en la unidad de CD virtual..."
qm set $VMID --ide2 $ISO_STORAGE:iso/$ISO_NAME,media=cdrom

# 5. Orden de arranque (Corregido con comillas para evitar el punto y coma de Bash)
echo "Configurando orden de arranque..."
qm set $VMID --boot "order=ide2;scsi0"

# 6. Agente de QEMU
echo "Activando el Agente QEMU en la configuracion de hardware..."
qm set $VMID --agent 1

echo "Despliegue de VM finalizado con exito."
echo "Accede a la consola de Proxmox, arranca la maquina $VMID y procede con la instalacion de pfSense."
