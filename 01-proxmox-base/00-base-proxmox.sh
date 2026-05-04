#!/bin/bash

echo "Iniciando configuración base de Proxmox (Fase 0)..."

# 1. Deshabilitar el repositorio 'Enterprise' (que da error si no pagas licencia)
echo "Ajustando repositorios..."
sed -i "s/^deb/#deb/g" /etc/apt/sources.list.d/pve-enterprise.list

# 2. Añadir el repositorio 'No-Subscription' (gratuito y legal)
cat <<EOF > /etc/apt/sources.list.d/pve-no-subscription.list
deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription
EOF

# 3. Actualizar la lista de paquetes y el sistema
echo "Actualizando el sistema"
apt update -y

# 4. Instalar herramientas esenciales para el resto del proyecto
echo "Instalando utilidades básicas..."
apt install -y curl wget htop sudo git unzip sudo

echo "¡Fase 0 completada con éxito! El host Proxmox está listo."
