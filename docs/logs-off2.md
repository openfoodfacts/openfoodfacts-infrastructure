# off2 server logs

Report here the timeline of incidents and interventions on off2 server.
Keep things short or write a report.

## 2023-01-19

see [2024-01-19 Certbot failure on off2 reverse proxy](./reports/2024-01-19-certbot-failure-off2-proxy.md)

## 2023-01-02

openpetfoodfats.org answers with a 502 bad gateway.
`curl --header "Host: world.openpetfoodfacts.org" http://10.1.0.110:80/` does not work from proxy, while it works from off2.
The problem solves as I launch a `ping 10.1.0.101` from opff (110)…
I think it's an ARP problem.

## 2023-10-23 (VM 101) openpetfoodfacts SSL certificate expired

The website https://fr.openpetfoodfacts.org use a certificate expired on 2023-10-20 and emited on july 22th.
`certbot renew` says nothing is to be renewed.
Looked at `/etc/letsencrypt/live/openpetfoodfacts.org/` and `/etc/letsencrypt/archive/openpetfoodfacts.org/` and configuration, all seems ok.
Finally a `systemctl reload nginx` did it.

## 2023-06-12 container 110 not reachable from 101

see [reports/2023-05-off2-110-unreachable.md](./reports/2023-05-off2-110-unreachable.md)

## 2023-06-02 container 110 not reachable from 101

see [2023-05-off2-110-unreachable.md](./reports/2023-05-off2-110-unreachable.md)

## 2023-05-23 container 110 not reachable from 101

see [reports/2023-05-off2-110-unreachable.md](./reports/2023-05-off2-110-unreachable.md)
