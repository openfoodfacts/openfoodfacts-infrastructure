# Monitoring external check role

Checks the monitoring stack (prometheus, grafana…) from another server,
because alertmanager can't alert about its own outage
(see [2026-10-19 report](../../../docs/reports/2026-10-19-monitoring-01-stack-down-after-deploy.md)).

It installs a systemd timer which runs `check_monitoring_stack.sh`
every `monitoring_external_check__interval` (15 min by default).
The script checks every url in `monitoring_external_check__urls` returns a 200.

When the stack is down, an email is sent (via `email-failures@`, see `systemd_email_failures` role),
at most once every `monitoring_external_check__alert_every_minutes` (once a day by default).
When it is back after an alert, a "monitoring stack is back" email is sent.

The date of last alert is kept in `/var/lib/monitoring_external_check/last_alert`.

It should be installed on only one server
(set `monitoring_external_check__enabled: true` in its host_vars),
otherwise we get one email per server.
