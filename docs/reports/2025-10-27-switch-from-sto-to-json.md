# 2025-10-27 Switch to using JSON instead of STO for Product files

For each service:

* OBF
* OPFF
* OPF
* OFF-PRO
* OFF

Edit Config2.pm and set `$serialize_to_json = 2;`

Restart services as per https://openfoodfacts.github.io/openfoodfacts-server/dev/how-to-release/

View a product (didn't want to make any artificial edits)

## Completion Status (UTC)

* OBF: 2025-10-27 16:21
* OPFF: 2025-10-27 16:24
* OPF: 2025-10-27 16:25
* OFF-PRO: 2025-10-27 16:27
* OFF: 2025-10-27 16:30

## Check events in off-query to find recent edits

```
select message->>'code', message->>'product_type', received_at from product_update_event order by received_at desc limit 10;
```

food: 433/725/684/4727
beauty: 044/400/844/2729
product: 685/677/357/6106
petfood: No recent edits

