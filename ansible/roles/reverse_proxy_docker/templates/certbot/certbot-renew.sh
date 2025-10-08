# {{ ansible_managed }}

# This command is run as the entrypoint of the certbot container
# there is a cron job that starts the container regularly
# see the files/certbot/cron-start-certbot.sh script


certbot certonly \
    --non-interactive \
    --agree-tos \
    --renew-with-new-domains \
    --cert-name "certificate" \
    --preferred-challenges dns-01 \
    --dns-ovh \
    --dns-ovh-credentials /config/ovh.ini \
    -m "{{ secrets_infra_email }}" \
{% for domain in reverse_proxy_https_cert_domains %}
    -d "{{ domain }}" \
    -d "*.{{ domain }}" \
{% endfor %}
