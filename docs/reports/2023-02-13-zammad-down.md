# 2023-02-13 Zammad down

Symptom: 502 Bad gateway on https://support.openfoodfacts.org/

Investigation:

Using systemctl status I see that :

```bash
$ systemctl status zammad-web-1.service
● zammad-web-1.service
   Loaded: loaded (/etc/systemd/system/zammad-web-1.service; enabled; vendor preset: enabled)
   Active: failed (Result: exit-code) since Mon 2023-02-13 09:43:14 UTC; 33s ago
  Process: 137673 ExecStart=/usr/bin/zammad run web (code=exited, status=1/FAILURE)
 Main PID: 137673 (code=exited, status=1/FAILURE)
```

Trying a restart, is not working.

```bash
$ systemctl status zammad-web-1.service
● zammad-web-1.service
   Loaded: loaded (/etc/systemd/system/zammad-web-1.service; enabled; vendor preset: enabled)
   Active: failed (Result: exit-code) since Mon 2023-02-13 09:44:27 UTC; 49s ago
  Process: 137995 ExecStart=/usr/bin/zammad run web (code=exited, status=1/FAILURE)
 Main PID: 137995 (code=exited, status=1/FAILURE)

févr. 13 09:44:27 off-zammad systemd[1]: zammad-web-1.service: Main process exited, code=exited, sta
févr. 13 09:44:27 off-zammad systemd[1]: zammad-web-1.service: Failed with result 'exit-code'.
févr. 13 09:44:27 off-zammad systemd[1]: zammad-web-1.service: Service hold-off time over, schedulin
févr. 13 09:44:27 off-zammad systemd[1]: zammad-web-1.service: Scheduled restart job, restart counte
févr. 13 09:44:27 off-zammad systemd[1]: Stopped zammad-web-1.service.
févr. 13 09:44:27 off-zammad systemd[1]: zammad-web-1.service: Start request repeated too quickly.
févr. 13 09:44:27 off-zammad systemd[1]: zammad-web-1.service: Failed with result 'exit-code'.
févr. 13 09:44:27 off-zammad systemd[1]: Failed to start zammad-web-1.service.
```

Looking at logs I see:

```bash
$ journalctl -u zammad-web-1.service -r

févr. 13 09:44:27 off-zammad zammad-web-1.service[137995]: Exiting
févr. 13 09:44:27 off-zammad zammad-web-1.service[137995]: A server is already running. Check /opt/zammad/tmp/pids/server.pid.
févr. 13 09:44:27 off-zammad zammad-web-1.service[137995]: => Run `rails server --help` for more startup options
févr. 13 09:44:27 off-zammad zammad-web-1.service[137995]: => Rails 6.0.4.6 application starting in production
févr. 13 09:44:27 off-zammad zammad-web-1.service[137995]: => Booting Puma
```

Looking at  `/opt/zammad/tmp/pids/server`, the pid is 156 which does not correspond to a zammad process:
```bash
ps -elf|grep 156
0 S root         156       1  0  80   0 - 71564 sys_po févr.12 ?     00:00:00 /usr/lib/accountsservice/accounts-daemon
```

I don't see any zombie process corresponding to zammad with `ps -elf`

So I decided to remove the PID file and relaunch:

```bash
rm /opt/zammad/tmp/pids/server.pid
systemctl restart zammad-web-1.service
```