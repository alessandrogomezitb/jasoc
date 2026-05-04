#!/bin/bash
# ==============================================================================
# Script: 14-preparar-web-docker.sh
# Proyecto: JASOC (Infraestructura MSSP)
# Descripción: Prepara la VM DMZ (JASOC-WEB) instalando el motor Docker
# ==============================================================================

set -e
export DEBIAN_FRONTEND=noninteractive

echo "[*] 1. Actualizando repositorios y el sistema base..."
apt update -y && apt upgrade -y

echo "[*] 2. Instalando dependencias necesarias..."
apt install -y ca-certificates curl gnupg lsb-release

echo "[*] 3. Añadiendo la clave GPG oficial de Docker..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg

echo "[*] 4. Añadiendo el repositorio de Docker a Debian..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "[*] 5. Instalando Docker y Docker Compose..."
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

echo "[*] 6. Creando la estructura de carpetas base..."
mkdir -p /opt/jasoc-web/{nginx,nextcloud}

echo "========================================================================="
echo "[V] JASOC-WEB PREPARADO CON ÉXITO."
echo "Docker versión: $(docker --version)"
echo "Ruta del proyecto: /opt/jasoc-web"
echo "========================================================================="
