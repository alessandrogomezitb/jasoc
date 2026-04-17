#!/bin/bash

echo "Iniciando descarga de ISOs necesarias (Fase 1)..."

# Directorio por defecto de Proxmox para las ISOs
ISO_DIR="/var/lib/vz/template/iso"

# URLs de descarga
PFSENSE_URL="https://pinguin.dinus.ac.id/iso/pfSense/iso/pfSense-CE-2.7.2-RELEASE-amd64.iso.gz"
#SI, ES UNA URL DE UNA UNIVERSIDAD, PERO ES QUE PFSENSE OBLIGA A REGISTRARSE PARA DESCARGAR ISOS AHORA

echo "Descargando pfSense..."
wget -q --show-progress -O $ISO_DIR/pfSense.iso.gz $PFSENSE_URL
echo "Descomprimiendo pfSense..."
gunzip -f $ISO_DIR/pfSense.iso.gz

echo "Descargando Debian 13 (Netinst)..."
wget -q --show-progress -O $ISO_DIR/debian-13.iso $DEBIAN_URL

echo "¡Fase 1 completada! Las ISOs están listas en $ISO_DIR."
