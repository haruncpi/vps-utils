#!/bin/bash
# Usage: sudo bash nginx-php-mysql example.com --php=8.2 --mysql=8.0
# One-liner: bash <(curl -fsSL https://raw.githubusercontent.com/haruncpi/vps-utils/master/nginx-php-mysql.sh) example.com --php=8.2 --mysql=8.0

set -e

DOMAIN=""
PHP_VERSION="8.2"
MYSQL_VERSION="8.0"

# --- Parse flags ---
for arg in "$@"; do
  case $arg in
    --php=*)
      PHP_VERSION="${arg#*=}"
      shift
      ;;
    --mysql=*)
      MYSQL_VERSION="${arg#*=}"
      shift
      ;;
    *)
      if [ -z "$DOMAIN" ]; then
        DOMAIN="$arg"
      fi
      shift
      ;;
  esac
done

if [ -z "$DOMAIN" ]; then
  echo "❌ Usage: sudo bash $0 yourdomain.com [--php=8.3] [--mysql=8.0]"
  exit 1
fi

echo "🚀 Installing Nginx + PHP $PHP_VERSION + MySQL $MYSQL_VERSION for $DOMAIN"

# --- Update system ---
apt update -y && apt upgrade -y

# --- Install prerequisites ---
apt install -y software-properties-common ca-certificates curl lsb-release apt-transport-https

# --- Add Ondrej PHP PPA (modern PHP versions) ---
if ! grep -q "ondrej/php" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
  add-apt-repository ppa:ondrej/php -y
fi

apt update -y

# --- Install Nginx ---
apt install -y nginx certbot python3-certbot-nginx unzip curl

# --- Install PHP and common extensions ---
apt install -y php$PHP_VERSION php$PHP_VERSION-fpm php$PHP_VERSION-mysql \
  php$PHP_VERSION-cli php$PHP_VERSION-curl php$PHP_VERSION-zip \
  php$PHP_VERSION-xml php$PHP_VERSION-mbstring php$PHP_VERSION-bcmath \
  php$PHP_VERSION-gd php$PHP_VERSION-intl php$PHP_VERSION-soap \
  php$PHP_VERSION-readline

# --- Install MySQL ---
# Use default Ubuntu repo (for simplicity)
# If you need exact version, add MySQL APT repo
apt install -y mysql-server

# --- Setup Nginx directories ---
mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled
mkdir -p /var/www/$DOMAIN/public
chown -R www-data:www-data /var/www/$DOMAIN
chmod -R 755 /var/www/$DOMAIN

# --- Create Nginx virtual host ---
cat > /etc/nginx/sites-available/$DOMAIN <<EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;

    root /var/www/$DOMAIN/public;
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php$PHP_VERSION-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/$DOMAIN

# --- Test Nginx ---
nginx -t
systemctl restart nginx
systemctl enable nginx

# --- Add PHP info test page ---
echo "<?php phpinfo(); ?>" > /var/www/$DOMAIN/public/index.php

# --- SSL setup ---
certbot --nginx -d $DOMAIN -d www.$DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN || true

# --- Restart services ---
systemctl restart php$PHP_VERSION-fpm mysql nginx

echo ""
echo "✅ Setup complete!"
echo "🌐 Site: https://$DOMAIN"
echo "📦 PHP version: $PHP_VERSION"
echo "🗄️  MySQL version: $MYSQL_VERSION"
echo ""