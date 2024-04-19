# off3 server logs

Report here the timeline of incidents and interventions on off3 server.
Keep things short or write a report.

## 2023-10-14 and 15 MongoDB not responding

See [2023-10-14: mongodb-down](./reports/2023-10-14-mongodb-down.md)

## 2023-05-23 unable to connect from opff on off2 after reboot
Added:
```bash
sudo ip route add 10.1.0.0/16 dev ens19 proto kernel scope link src 10.0.0.3
```

## 2023-05-19 Mongodb down

see [2023-05-18 Mongodb down](./reports/2023-05-19-overload-of-osm-machine.md)


## 2023-05-05 Mongodb access from off2

see [*Mongodb access* in 2023-03 OFF2 reinstall - opff migration](./reports/2023-03-14-off2-opff-reinstall.md#mongodb-access)

## 2023-12-17 Mongodb down

Started at 6:25am.
In mongodb logs:
```json
{"t":{"$date":"2023-12-17T10:40:30.014+01:00"},"s":"I",  "c":"NETWORK",  "id":22942,   "ctx":"listener","msg":"Connection refused because there are too many open connections","attr":{"connectionCount":301}}
```
Restarted by Charles (on sunday).