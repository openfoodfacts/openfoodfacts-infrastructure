# Move EAN8 directories

See https://github.com/openfoodfacts/openfoodfacts-server/issues/3818

## Move script move_ean8_products_to_new_path.pl

The script goes through product directories that are at the root of the products directory,
and move product directories to a structured path.

e.g. 99723824 to 000/009/972/3824

The script is made to work on both the new codebase (running on OFF) and the old code base (running on OPF, OBF, OPFF).

At first, the script does not do the move, but checks how many products would be impacted:

## Impacted products

### OFF

254867 products at the root - 0 products not empty or deleted
invalid code: 2
moved: 248924
not moved: 5942
same path: 0
changed code: 65599

### OPFF

1054 products at the root - 0 products not empty or deleted
invalid code: 1
moved: 1054
not moved: 0
same path: 0
changed code: 397

### OPF

1480 products at the root - 0 products not empty or deleted
invalid code: 1
moved: 1480
not moved: 0
same path: 0
changed code: 417

### OBF

3983 products at the root - 0 products not empty or deleted
invalid code: 1
moved: 3969
not moved: 14
same path: 0
changed code: 1487

## Moving products

We need to move products on OFF, OBF, OPF and OPFF roughly at the same time, in order to avoid issues if products are moved from one flavor to another that uses a different barcode to path mapping.

### Code normalization

As short barcodes are padded with 0s, we need to make sure that we normalize unpadded barcodes and padded barcodes to the same barcode. As EAN8 are primarily referred to with 8 digit barcodes, we have decided before to normalize to 8 digits.

Normalization with current code on OFF + OBF / OPF / OPFF:

- UPC12 (only the ones that are valid EANs) / EAN13 / 0 + EAN13 : normalized to 13 digits
- EAN8 : normalized to 8 digits

In practice we have some products currently stored with EAN8s padded with 0s with paths like 000/006/911/0146
Those are currently not reachable (read or write), and are likely to contain outdated data.

### Products that are not at the root but not at the right padded path

There are some products with 4, 5, 6, 7, (not 8), 9, 10, 11 digits:
https://world.openfoodfacts.org/product/00000111222/pollo-fino-scharf
That are stored in paths like:
000/001/112/22/

We should pad the paths to 13 digits:
000/000/011/1222/

Those products need to be moved as well, otherwise they won't be reachable.

### New normalization

In order to not have different products with codes that differ only by leading 0s,
I'm changing the normalization so that:

Leading 0s are removed for codes with more than 13 digits.
Leading 0s are added so that we have 13 digits.
Except when leading 0s can be removed in order to have only 8 digits.

### Products with changed codes update

Need to:
- remove old code from MongoDB
- notify REDIS of removal of old code
- update new code in .sto file (in a new revision, for better traceability, and possible rollback)
- update mongodb

### Test

Tested locally in dev environment with 10k products.

## What to do with conflicting products?

### Products that already exist on the new path, but also on the old path

This is possible when products were also created with extra leading 0s (e.g. if a scanner or a producer added 0s).

DECISION: assume the old path is more likely to contain better data. Move the new path to a backup folder, and the old path to the new path.

On OFF we have 5942 products with conflicts (that exist in multiple paths).

## Migration plan

### Move OBF, OPF, OPFF to new code first

Otherwise we would need to make similar changes to the normalization on the old code.

### Risks of race conditions

#### Old path from a not yet migrated flavor moved to an already migrated flavor

If OBF / OPF / OPFF / OFF is updated while another flavor is not, and we move an old path to a flavor that has already been updated:

- If the product does not exist on the target flavor, it gets an old path. We could run again the migration scripts on all flavors one more time, once all flavors have been updated once.
- If the product exists on the target flavor, we will miss it.

If we do the moves of all flavors on the same day, the risk is rather small.

One way to avoid it could be to disable moving products while we migrate. But it's more steps for a rather small benefit.

DECISIONS:
- Migrate OFF first, as most products get moved from OFF to other flavors. Then move other flavors.
- Ask moderators not to move products during the migration.

#### New normalization / path generation code live, but products not yet migrated

When we update one flavor, the new normalization and path generation code will be live, but the products will take time to migrate. In the mean time, those products will appear to be non-existing if someone tries to access their product page (or call the API).

One option could be to stop the service while we run the migration script (but it might take hours, especially on OFF where we need to move 250k products.

Or we could change the code to make it work with both old paths and new paths.

DECISION: change the Product Opener code (split_code function) so that if the old normalized path exist (which means the product has not been migrated), we use it.

### Steps:

1. Move OBF, OPF, OPFF to new code (before the PR https://github.com/openfoodfacts/openfoodfacts-server/pull/10472 is merged)
2. Migrate OFF
- Ask moderators not to move products
- Deploy https://github.com/openfoodfacts/openfoodfacts-server/pull/10472 on OFF
- Stop and start Apache, so that Product Opener can read and write products on both the old path (if it exists) and the new path
- Run the migration script to migrate products from the old paths to the new paths
3. Migrate OBF, OPF, OPFF
4. Create a PR to remove the code that checks if the old path exists.

## Migration

Started migration on 2024/10/02.

Changed initial plan to start with OPFF first, in order to uncover issues in a less used environment (much fewer products and updates)

### OPFF

Dry run in OPFF:

Fixed some permissions in /mnt/opff (some directories like "logs" were owned by root, changed to off:off)

1099 products at the root
invalid code: 1 -> "invalid"
moved: 1098
not moved: 0
same path: 0
changed code: 417

Fixed: Issue with products that are deleted, they should not be added back to mongodb.

There's an issue with products have a changed code (not only a changed path) with leading 0s: they can't be retrieved until they are moved. Fixing by removing leading 0s in old_split_code(). This partially work: if a product code already has some leading 0s but not the right number, the new code won't find the product until it has migrated. It could be fixed, but probably not worth the complexity.

Also disabling the redirect from old code to new code in order not to have redirect loops.
TODO: will need to reenable the redirect once the migration is complete.

There are some products with 1 or 2 digits. Those are most likely bogus. We will remove those products instead of padding them with zeroes. The corresponding files are moved to products/invalid-barcodes

### Conflicts on OPFF

new path exists, not moving 527/427/749/0 to 000/527/427/7490
new path exists, not moving 649/922/801/7 to 000/649/922/8017

### OBF

4226 products at the root or not split into a 4 component path
57 products paths containing other products
invalid code: 0
moved: 4210
not moved: 16
same path: 0
changed code: 1663

### Conflicts on OBF

22 products to update
new path exists, not moving 000/000/000/00 to 000/000/000/0000
new path exists, not moving 0006 to 000/000/000/0006
new path exists, not moving 00432 to 000/000/000/0432
new path exists, not moving 06147198 to 000/000/614/7198
new path exists, not moving 101/810/403/13 to 001/018/104/0313
new path exists, not moving 1048 to 000/000/000/1048
new path exists, not moving 1211 to 000/000/000/1211
new path exists, not moving 123/456/789/05 to 001/234/567/8905
new path exists, not moving 1262 to 000/000/000/1262
new path exists, not moving 187/879/433/59 to 001/878/794/3359
new path exists, not moving 191/001/943/04 to 001/910/019/4304
new path exists, not moving 207/142/228/57 to 002/071/422/2857
new path exists, not moving 227/969/161/12 to 002/279/691/6112
new path exists, not moving 263/950/011/63 to 002/639/500/1163
new path exists, not moving 30106659 to 000/003/010/6659
new path exists, not moving 370/012/430/6 to 000/370/012/4306
new path exists, not moving 565/940/046/72 to 005/659/400/4672
new path exists, not moving 62263436 to 000/006/226/3436
new path exists, not moving 705/010/171/04 to 007/050/101/7104
new path exists, not moving 705/010/270/04 to 007/050/102/7004
new path exists, not moving 705/010/609/57 to 007/050/106/0957
new path exists, not moving 794/000/134/39 to 007/940/001/3439

Note: now moving conflicts to products/conflicting-codes/

# OPF

11 products paths containing other products
invalid code: 0
moved: 1542
not moved: 0
same path: 0
changed code: 443

# OFF

271562 products at the root or not split into a 4 component path
621 products paths containing other products
invalid code: 0
moved: 262432
not moved: 9130
same path: 0
changed code: 68061

## Serving images with old image paths

Robotoff and some 3rd party apps compute themselves the paths of the images.
This means that they will use the old paths, unless they are updated.

To avoid serving 404s, we add rules in the nginx proxy of the product opener containers to be able to serve images with the old paths:

```
location ~ ^/images/products/ {
        # 2024/10/03 - temporary redirects as we changed the path of images
        # for barcodes that are 8 digits or less
        rewrite ^/images/products/(....)/([^/]*)$ /images/products/000/000/000/$1/$2 break;
        rewrite ^/images/products/(.)(....)/([^/]*)$ /images/products/000/000/00$1/$2/$3 break;
        rewrite ^/images/products/(..)(....)/([^/]*)$ /images/products/000/000/0$1/$2/$3 break;
        rewrite ^/images/products/(...)(....)/([^/]*)$ /images/products/000/000/$1/$2/$3 break;
        rewrite ^/images/products/(.)(...)(....)/([^/]*)$ /images/products/000/00$1/$2/$3/$4 break;
        rewrite ^/images/products/(..)(...)(....)/([^/]*)$ /images/products/000/0$1/$2/$3/$4 break;
```

A better solution could be to return 302 redirects.

One issue during the migration is that we cannot have the rules active until all products are migrated.
One way to avoid that could have been to use try_file instead of redirects... 