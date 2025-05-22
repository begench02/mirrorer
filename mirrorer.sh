#!/bin/bash

if [ "$#" -ne 4 ]; then
  echo "Неправильные параметры: $0 <donor_fqdn> <keyword> <user@host:/var/www/domain> <password>"
  exit 1
fi

DONOR="$1"
KEYWORD="$2"
REMOTE="$3"
PASSWORD="$4"

REMOTE_USER_HOST=$(echo "$REMOTE" | cut -d: -f1)
REMOTE_PATH=$(echo "$REMOTE" | cut -d: -f2)

DOMAIN=$(echo "$DONOR" | sed -E 's~https?://~~; s/^www\.//; s/^([^.]+)\..*$/\1/')
NAME="${DOMAIN}.fihosu.com"
TMP_DIR="./temp_$NAME"
ZIP_FILE="$NAME.zip"

rm -rf "$TMP_DIR" "$ZIP_FILE"

echo "Скачивание сайта $DONOR..."
wget \
  --recursive \
  --no-clobber \
  --convert-links \
  --page-requisites \
  --no-host-directories \
  --cut-dirs=1 \
  --directory-prefix="$TMP_DIR" \
  "$DONOR"

echo "Вставка ключевых слов"
node add-keywords.js "$KEYWORD" "$TMP_DIR"

echo "Архивирование"
(cd "$TMP_DIR" && zip -qr "../$ZIP_FILE" .)

echo "Отправка архива на сервер $REMOTE_USER_HOST"
sshpass -p "$PASSWORD" ssh "$REMOTE_USER_HOST" "sudo mkdir -p '$REMOTE_PATH'"
sshpass -p "$PASSWORD" scp "$ZIP_FILE" "$REMOTE_USER_HOST:/tmp/$ZIP_FILE"

echo "Распаковка архива"
sshpass -p "$PASSWORD" ssh "$REMOTE_USER_HOST" "sudo unzip -o /tmp/$ZIP_FILE -d '$REMOTE_PATH/$NAME' && sudo rm /tmp/$ZIP_FILE"

echo "Создание конфигурации Nginx для ${NAME}"

sshpass -p "$PASSWORD" ssh "$REMOTE_USER_HOST" "sudo tee /etc/nginx/sites-enabled/${NAME}.conf > /dev/null" <<EOF
server {
    listen 185.185.68.56:443 ssl;
    server_name ${NAME};

    ssl_certificate /etc/nginx/ssl/fihosu.com/fullchain.cer;
    ssl_certificate_key /etc/nginx/ssl/fihosu.com/fihosu.com.key;

    root $REMOTE_PATH/$NAME;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php$ {
      include snippets/fastcgi-php.conf;
      fastcgi_pass unix:/run/php/php8.1-fpm.sock;
    }

    location ~ /\.ht {
      deny all;
    }
}

server {
  listen 185.185.68.56:80;
  server_name ${NAME};

  if (\$host = ${NAME}) {
    return 301 https://\$host\$request_uri;
  }
  return 404;
}
EOF


echo "Перезагрузка NGINX"
sshpass -p "$PASSWORD" ssh "$REMOTE_USER_HOST" "sudo nginx -t && sudo systemctl reload nginx" 

echo "Удаление временных файлов"
rm -rf "$TMP_DIR" "$ZIP_FILE"
