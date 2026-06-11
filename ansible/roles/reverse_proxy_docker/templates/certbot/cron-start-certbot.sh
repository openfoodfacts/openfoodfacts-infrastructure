# {{ ansible_managed }}

# This script is started by a cron job to renew the certificates
# it starts the 'certbot' container, which starts the 'templates/certbot/certbot-renew.sh' script
# the container then stops

cd {{ reverse_proxy_docker__dir }}

docker compose up certbot --timestamps
docker compose exec reverse_proxy nginx -s reload
