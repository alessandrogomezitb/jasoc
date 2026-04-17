#!/bin/bash

echo "Iniciando creación de la Plantilla Base Cloud-Init (Fase 3)..."

# Variables
TEMPLATE_ID=9000
TEMPLATE_NAME="Plantilla-Debian-12-Base"
# Usamos la imagen genérica diaria de Debian 12 ACLARAR EN LA MEMORIA!!
IMAGE_URL="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2"
IMAGE_NAME="debian-13-cloud.qcow2"

# 1. Descargar la imagen Cloud de Debian 12
echo "Descargando imagen Cloud de Debian 12..."
wget -q --show-progress -O $IMAGE_NAME $IMAGE_URL

# 2. Crear la Máquina Virtual base (vacía)
echo "Creando la VM base con ID $TEMPLATE_ID..."
qm create $TEMPLATE_ID --name $TEMPLATE_NAME --memory 2048 --cores 2 --net0 virtio,bridge=vmbr1

# 3. Importar el disco descargado al almacenamiento local de Proxmox (local-lvm)
echo "Importando el disco a Proxmox (esto puede tardar un poco)..."
qm importdisk $TEMPLATE_ID $IMAGE_NAME local-lvm

# 4. Configurar el hardware de la VM para que use el disco importado y Cloud-Init
echo "Configurando hardware y Cloud-Init..."
qm set $TEMPLATE_ID --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-$TEMPLATE_ID-disk-0
qm set $TEMPLATE_ID --ide2 local-lvm:cloudinit
qm set $TEMPLATE_ID --boot c --bootdisk scsi0
qm set $TEMPLATE_ID --serial0 socket --vga serial0

# 5. Convertir la Máquina Virtual en una Plantilla
echo "Convirtiendo la VM en Plantilla..."
qm template $TEMPLATE_ID

# 6. Limpieza del archivo descargado
rm $IMAGE_NAME

echo "¡Fase 3 completada!"
