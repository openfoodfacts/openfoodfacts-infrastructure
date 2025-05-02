# {{ ansible_managed }}

certbot certonly \
    --test-cert \
    --non-interactive \
    --agree-tos \
    --renew-with-new-domains \
    --cert-name "certificate" \
    --preferred-challenges dns-01 \
    --dns-ovh \
    --dns-ovh-credentials /config/ovh.ini \
    -m "{{ secrets_infra_email }}" \
    -d "{{ reverse_proxy_https_domain }}" \
    -d "*.{{ reverse_proxy_https_domain }}"