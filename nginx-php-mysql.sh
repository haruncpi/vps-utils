#!/bin/bash
# Usage: sudo bash nginx-php-mysql example.com --php=8.3 --mysql=8.0
# One-liner: bash <(curl -fsSL https://raw.githubusercontent.com/haruncpi/vps-utils/main/nginx-php-mysql.sh) example.com --php=8.3 --mysql=8.0

DOMAIN=""
PHP_VERSION="8.2"
MYSQL_VERSION="8.0"

# --- Parse arguments ---
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
  echo "❌ Usage: sudo bash nginx-php-mysql yourdomain.com [--php=8.3] [--mysql=8.0]"
  exit 1
fi

echo "🚀 Setting up $DOMAIN with PHP $PHP_VERSION and MySQL $MYSQL_VERSION"

# --- Update system ---
apt update -y

# --- Install MySQL ---
apt install -y mysql-server
# (Optional: version control depends on available repos)

# --- Install PHP ---
add-apt-repository ppa:ondrej/php -y
apt update -y
apt install -y nginx php$PHP_VERSION php$PHP_VERSION-fpm php$PHP_VERSION-mysql php$PHP_VERSION-cli php$PHP_VERSION-curl php$PHP_VERSION-zip php$PHP_VERSION-xml php$PHP_VERSION-mbstring php$PHP_VERSION-bcmath php$PHP_VERSION-gd php$PHP_VERSION-intl php$PHP_VERSION-soap php$PHP_VERSION-readline unzip curl certbot python3-certbot-nginx

# --- Setup directories ---
mkdir -p /var/www/$DOMAIN/public
chown -R www-data:www-data /var/www/$DOMAIN
chmod -R 755 /var/www/$DOMAIN

# --- Nginx config ---
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

ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

# --- Test PHP page ---
echo "<?php phpinfo(); ?>" > /var/www/$DOMAIN/public/index.php

# --- SSL setup ---
certbot --nginx -d $DOMAIN -d www.$DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN || true

# --- Restart services ---
systemctl restart nginx php$PHP_VERSION-fpm mysql

echo ""
echo "✅ Setup complete!"
echo "🌐 https://$DOMAIN"
echo "📦 PHP version: $PHP_VERSION"
echo "🗄️  MySQL version: $MYSQL_VERSION"
echo ""