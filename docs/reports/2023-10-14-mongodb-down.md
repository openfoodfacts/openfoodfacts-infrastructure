# 2023-10-14: mongodb-down

## What happened?

* On Sunday, 2023-10-14 from ~12:00 (maybe before) to 17:55 CEST, Open Food Facts core websites (world.openfoodfacts.org + [all.countries].openfoodfacts.org) were experiencing issues: either "Software error" or "No products" when asking for a list of products.
* API and core websites were working for product pages, eg. https://world.openfoodfacts.org/product/3168930010265/cruesli-melange-de-noix-quaker
* On off3, hosting mongodb, load were very high and 80+ of the ram was full.

## Solving
Around 17:55 I just restarted mongodb -- `systemctl restart mongod`  --  and things get back to work: load get back to ~1, RAM was arround 50%, sites were working.

## Later on
Same issue occurs on Sunday at ~10:55, except server load and RAM were normal. I have also restarted mongod and things get back to work.
