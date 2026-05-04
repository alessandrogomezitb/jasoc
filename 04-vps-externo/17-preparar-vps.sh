#!/bin/bash
# ==============================================================================
# Script: 17-preparar-vps.sh (VERSIÓN SECURIZADA)
# Proyecto: JASOC (Infraestructura MSSP)
# Descripción: Proxy inverso seguro con HTTPS + hardening básico + modo seguro SSH
# ==============================================================================

set -e

# --- VARIABLES DE CONFIGURACIÓN ---
DOMINIO="jasoc.cat"
IP_NEXTCLOUD="192.168.10.2"
EMAIL="admin@jasoc.cat"

# 🔐 Control de SSH
SSH_SOLO_TAILSCALE="${SSH_SOLO_TAILSCALE:-false}"
TAILSCALE_IF="${TAILSCALE_IF:-tailscale0}"
# ----------------------------------

echo "[*] 1. Actualizando sistema..."
apt-get update -y

echo "[*] 2. Instalando paquetes..."
apt-get install -y nginx ufw fail2ban certbot python3-certbot-nginx

# ------------------------------------------------------------------------------
# FIREWALL
# ------------------------------------------------------------------------------
echo "[*] 3. Configurando firewall (UFW)..."

ufw --force reset
ufw default deny incoming
ufw default allow outgoing

ufw allow 80/tcp
ufw allow 443/tcp

if [ "$SSH_SOLO_TAILSCALE" = "true" ]; then
    echo "[*] SSH SOLO por Tailscale..."
    ufw allow in on "$TAILSCALE_IF" to any port 22 proto tcp
else
    echo "[!] SSH público TEMPORALMENTE abierto"
    ufw allow 22/tcp
fi

ufw --force enable

# ------------------------------------------------------------------------------
# FAIL2BAN
# ------------------------------------------------------------------------------
echo "[*] 4. Activando fail2ban..."
systemctl enable fail2ban
systemctl restart fail2ban

# ------------------------------------------------------------------------------
# NGINX CONFIG (HTTP inicial para certbot)
# ------------------------------------------------------------------------------
echo "[*] 5. Configurando Nginx (HTTP inicial)..."

cat << EOF > /etc/nginx/sites-available/nextcloud_proxy.conf
server {
    listen 80 default_server;
    server_name _;
    return 444;
}

server {
    listen 80;
    server_name $DOMINIO www.$DOMINIO;

    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    location / {
        return 301 https://\$host\$request_uri;
    }
}
EOF

ln -sf /etc/nginx/sites-available/nextcloud_proxy.conf /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

systemctl restart nginx

# ------------------------------------------------------------------------------
# CERTIFICADO HTTPS
# ------------------------------------------------------------------------------
echo "[*] 6. Generando certificado SSL..."
certbot --nginx -d $DOMINIO -d www.$DOMINIO --non-interactive --agree-tos -m $EMAIL

# ------------------------------------------------------------------------------
# NGINX FINAL (PROXY SEGURO)
# ------------------------------------------------------------------------------
echo "[*] 7. Configurando proxy inverso seguro..."

cat << EOF > /etc/nginx/sites-available/nextcloud_proxy.conf
server {
    listen 80;
    server_name $DOMINIO www.$DOMINIO;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMINIO www.$DOMINIO;

    client_max_body_size 10G;

    ssl_certificate /etc/letsencrypt/live/$DOMINIO/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMINIO/privkey.pem;

    add_header Strict-Transport-Security "max-age=15552000" always;

    location / {
        proxy_pass http://$IP_NEXTCLOUD;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;

        # 🔴 CLAVE para Nextcloud detrás de proxy
        proxy_set_header X-Forwarded-Proto https;

        proxy_http_version 1.1;
        proxy_set_header Connection "";

        proxy_read_timeout 3600;
        proxy_connect_timeout 120;

        # Buffers (evita problemas tipo MTU / cortes)
        proxy_buffering on;
        proxy_buffers 16 64k;
        proxy_buffer_size 128k;
        proxy_busy_buffers_size 256k;
    }
}
EOF

echo "[*] 8. Reiniciando Nginx..."
systemctl restart nginx
systemctl enable nginx

# ------------------------------------------------------------------------------
# INFO FINAL
# ------------------------------------------------------------------------------
echo "========================================================================="
echo "[V] VPS SECURIZADO CORRECTAMENTE"
echo "- Dominio: https://$DOMINIO"
echo "- Proxy hacia: $IP_NEXTCLOUD"
echo "- Firewall: 80/443 abiertos"

if [ "$SSH_SOLO_TAILSCALE" = "true" ]; then
    echo "- SSH: SOLO por Tailscale ($TAILSCALE_IF)"
else
    echo "- SSH: público temporalmente abierto"
    echo ""
    echo "[!] SIGUIENTE PASO:"
    echo "    1. Probar acceso por Tailscale:"
    echo "       ssh usuario@IP_TAILSCALE"
    echo ""
    echo "    2. Ejecutar:"
    echo "       sudo SSH_SOLO_TAILSCALE=true bash $0"
fi

echo "========================================================================="
