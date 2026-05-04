#!/bin/bash
# ==============================================================================
# Script: 17-preparar-vps.sh
# Proyecto: JASOC (Infraestructura MSSP)
# Descripción: Instala Nginx y lo configura como Proxy Inverso hacia Nextcloud
# ==============================================================================

set -e

# --- VARIABLES DE CONFIGURACIÓN ---
DOMINIO="jasoc.cat"
IP_NEXTCLOUD="192.168.10.2"
# ----------------------------------

echo "[*] 1. Actualizando sistema e instalando Nginx..."
apt-get update -y
apt-get install -y nginx

echo "[*] 2. Configurando el Proxy Inverso (Virtual Host) para $DOMINIO..."
cat << EOF > /etc/nginx/sites-available/nextcloud_proxy.conf
server {
    listen 80;
    server_name $DOMINIO www.$DOMINIO;

    client_max_body_size 512M;

    location / {
        proxy_pass http://$IP_NEXTCLOUD;
        
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        proxy_read_timeout 90;
        proxy_connect_timeout 90;
    }
}
EOF

echo "[*] 3. Activando la configuración..."
ln -sf /etc/nginx/sites-available/nextcloud_proxy.conf /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

echo "[*] 4. Reiniciando Nginx para aplicar cambios..."
systemctl restart nginx
systemctl enable nginx

echo "========================================================================="
echo "[V] VPS PREPARADO CON ÉXITO."
echo "- Proxy Inverso activado para: $DOMINIO"
echo "- Tráfico redirigido por VPN a: $IP_NEXTCLOUD"
echo "========================================================================="
