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
- update new code in .sto file
- update mongodb

### Test

Tested locally in dev environment with 10k products.





