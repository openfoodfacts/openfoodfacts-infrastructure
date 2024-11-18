# 2024-11-15 Merge product dirs for all flavors

In the last few weeks, we normalized product barcodes and deduplicated products that existed in multiple flavors (Open Food Facts, Open Beauty Facts, Open Product Facts and Open Pet Food Facts).

We are now going to merge the directories that contain product and product revision data (the .sto files) and the product images. We will keep separate MongoDB databases for each flavor.

This will:

- make it much easier to move products from one product type to another
- remove the possibility of having duplicate products on multiple flavors
- make it much easier to have read and write APIs that can be used to retrieve / update products of any type.

Deployment plan:

- update OFF code, check everything works
- test moving the directories of 1 product from OPF to OFF
- test changing the product type of the test product back to OPF
- do the following one flavor at a time:
- stop OBF, OPF, OPFF for the duration of the migration (a couple of hours)
- move products and product images dirs from OBF, OPF, OPFF to the OFF directory structure
- change the links to products and products of images on OBF, OPF, OPFF to use the OFF dirs
- restart OBF, OPF, OPFF with the new code

## PR

https://github.com/openfoodfacts/openfoodfacts-server/pull/10959

## Deduplication

We deduplicated products earlier (see [2024-10-23 Deduplicate products in multiple flavors](./2024-10-23-deduplicate-products-in-multiple-flavors.md)) but I had forgotten to include the obsolete collections.

Ran the script 2024_10_detect_duplicate_products_in_different_flavors.pl again:

```bash
off@off:/srv/off$ (off) ./scripts/migrations/2024_10_detect_duplicate_products_in_different_flavors.pl

2407 duplicate products
```

A lot of those duplicate products are in fact products only on OFF, but in 2 collections (the normal + the obsolete one).
e.g. a lot of Carrefour and Auchan products (that sent us lists of obsolete products)
The root cause will have to be investigated and solved, but it doesn't prevent us from merging the product directories.

Reran the scripts  ./scripts/migrations/2024_10_remove_duplicate_products_on_wrong_flavors.pl to remove the duplicates.

## Migration

Deployed unified-paths branch on OFF. Everything seems ok.

Moved one product from OFF to OPF by changing the product type.

Deployed unified-paths branch on OPF, but did not change the products and products images paths to OFF.

```bash
off@opf-new:/srv/opf$ (opf) ./scripts/migrations/2024_11_move_obf_opf_opff_products_to_off_dirs.pl 
Found 19603 products
Products not existing on OFF: 17355
Products existing on OFF: 2248
Products existing on OFF but deleted on OFF: 1821
Products existing on OFF but deleted locally: 401
Products existing on OFF and not deleted on OFF or locally: 26
Dirs without product.sto: 0
Empty dirs: 0
```

Trying to move 1 product dir. Fixed some issues with move() not working because it is a different filesystem.
Using dirmove() instead. One issue is that it does not preserve file modified timestamps as it is in fact a copy.
We could use the system mv, but it's trickier to get failures etc. so I won't bother with it.

### OPFF

Found 13312 products
Products not existing on OFF: 10926
Products existing on OFF: 2386
Products existing on OFF but deleted on OFF: 2121
Products existing on OFF but deleted locally: 223
Products existing on OFF and not deleted on OFF or locally: 42
Dirs without product.sto: 0

### Migration issues

#### Speed

Migration started on Friday Nov 15 2024 and finished on Monday Nov 18.
Moving the product sto files and images from one file system to another was very slow (e.g. it took more than 24 hours for the 40k OBF products).
This is most certainly due to the overuse and latency issue we have been having on off2 disks.

#### Human error: off products mistakenly moved to opf other-flavor-products

I lost the connection to off2 and had to restart a script on OPF, but I restarted the wrong one (2024_11_move_obf_opf_opff_products_to_off_dirs.pl instead of 2024_11_move_missing_opf_products.pl) which had the unfortunate result of moving OFF products from /srv/off/products (which had already been changed to be the destination of /srv/opf/products) to /srv/opf/products/other-flavor-products

To fix the issue, I finished moving OBF, OPF and OPFF products to /srv/off/products, and then ran a script to move products from /srv/opf/products/other-flavor-products to /srv/off/products if they didn't exist there yet.


