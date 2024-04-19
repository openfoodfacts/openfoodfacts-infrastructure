# off1 server logs

Report here the timeline of incidents and interventions on off1 server.
Keep things short or write a report.

## 2023-09-05 exim paniclog

We have an alert since 09-03 because `/var/log/exim4/paniclog` is not empty.
Indeed it has a line saying `2023-09-03 04:17:57 daemon: fork of queue-runner process failed: Cannot allocate memory`
But appart from this it's all ok. Alert will remain until this paniclog is empty.
I did a:
```bash
cd /var/log/exim4; mv paniclog paniclog.1; systemctl reload exim4
```


## 2023-07-25 Disk full on /rpool/off/products

See [2023-07-26 rpool/off/products dataset full on off1](reports/2023-07-26-off1-rpool-products-full.md)
