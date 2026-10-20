#!/usr/bin/env bash

# Check the monitoring stack (prometheus, grafana…) from outside monitoring-01,
# because alertmanager can't alert about its own outage.
#
# Usage: check_monitoring_stack.sh <url> [<url>…]
# every url must answer with a 200 status code.
#
# It is run by monitoring_external_check.service which emails on failure.
# To avoid an email every run, we exit with an error at most once per day
# while the stack is down, and send a mail when it is back.

set -u

STATE_FILE="${STATE_DIRECTORY:-/var/lib/monitoring_external_check}/last_alert"
ALERT_EVERY_MIN="${ALERT_EVERY_MIN:-$((24*60))}"
MAIL_TO="${MAIL_TO:-root}"

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <url> [<url>…]" >&2
  exit 2
fi
URLS=("$@")

failed=0
for url in "${URLS[@]}"; do
  code=$(curl -sS -o /dev/null -m 20 --retry 2 --retry-delay 10 -w '%{http_code}' "$url")
  if [[ "$code" != "200" ]]; then
    echo "KO $url -> $code"
    failed=1
  else
    echo "OK $url"
  fi
done

if [[ $failed -eq 0 ]]; then
  if [[ -f "$STATE_FILE" ]]; then
    # we alerted before: tell we are back to normal
    printf "monitoring stack is back\n\nlast alert sent at: %s\n\nchecked urls:\n%s\n" \
      "$(date -r "$STATE_FILE")" "$(printf '%s\n' "${URLS[@]}")" \
      | mailx -s "[$(hostname)][monitoring_external_check] monitoring stack is back" "$MAIL_TO"
    # reset, so that next outage alerts immediately
    rm -f "$STATE_FILE"
  fi
  exit 0
fi

# still down: alert only if no alert was sent recently
if [[ -n $(find "$STATE_FILE" -mmin -"$ALERT_EVERY_MIN" 2>/dev/null) ]]; then
  echo "still failing, alert already sent at $(date -r "$STATE_FILE")"
  exit 0
fi
touch "$STATE_FILE"
exit 1
