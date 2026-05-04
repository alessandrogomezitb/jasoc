#!/bin/bash

echo "Iniciando configuración de Red por Software (Fase 2)..."

# Comprobar si vmbr1 ya existe
if grep -q "vmbr1" /etc/network/interfaces; then
    echo "La red vmbr1 ya existe. Saltando..."
else
    echo "Configurando vmbr1 (Red Blue Team / SOC)..."
    cat <<EOF >> /etc/network/interfaces

auto vmbr1
iface vmbr1 inet manual
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
# Red Privada para el SOC
EOF
fi

# Comprobar si vmbr2 ya existe
if grep -q "vmbr2" /etc/network/interfaces; then
    echo "La red vmbr2 ya existe. Saltando..."
else
    echo "Configurando vmbr2 (Red Red Team / Atacantes)..."
    cat <<EOF >> /etc/network/interfaces

auto vmbr2
iface vmbr2 inet manual
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
# Red Privada para los Atacantes
EOF
fi

# Aplicar los cambios de red en Proxmox sin reiniciar el servidor
ifreload -a
echo "¡Redes virtuales creadas y aplicadas con éxito!"
