#!/bin/bash
set -euo pipefail
dnf install -y nginx
SECRET=$(aws ssm get-parameter --region us-east-1 --name /novasphere/${environment}/db_password --with-decryption --query Parameter.Value --output text)
install -d -m 0750 -g nginx /etc/novasphere
(umask 027; printf 'DB_PASSWORD=%s\n' "$SECRET" > /etc/novasphere/app.conf)
printf '<h1>NovaSphere - %s</h1><p>Instance : %s</p><p>Secret Parameter Store : lu (%s caracteres)</p>\n' "${environment}" "$(hostname)" "$${#SECRET}" > /usr/share/nginx/html/index.html
systemctl enable --now nginx
