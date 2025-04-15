# 2024-10-23 Deduplicate products in multiple flavors

We are in the process of unifying the product databases for the different flavors: OFF, OBF, OPF and OPFF.

In the near future, we will keep separate databases in MongoDB for each flavor, but we want to merge the directories for the product data (.sto files) and images, in order to avoid duplicate products (products that exist in multiple flavors).

Before we can merge the product directories, we need to deduplicate products that already exist in multiple flavors.

## Identification of duplicate products

A script 2024_10_detect_duplicate_products_in_different_flavors.pl was developed to go through the off, obf, opf, and opff MongoDB collections to see which barcodes exist in multiple flavors.

The script was run first on 2024/08/12 and it identified 8584 products that exist on multiple flavors.

On 2024/10/23, the duplicate detection script found 8898 duplicate products.

## Selection of product to keep

### Manual review for top products

The 8584 duplicate products from 2024/08/12 were put on Google Sheets and a lot of products were manually assigned to one flavor: https://docs.google.com/spreadsheets/d/1-2WMvUC4J7iRYe3587mHJ1htIxPFyo7JLDLKHVmSum0/edit?gid=1565589772#gid=1565589772

In particular the manual review focused on popular products (with the most scans on OFF)

### Automatic selection for non manually reviewed products

For other products, we will keep the flavor that has the most data (size of .sto file).

## Deduplication

The script 2024_10_remove_duplicate_products_in_wrong_flavors.pl is used to move product data and images to the products/other-flavors-code directory (same for images/products). Removed products are also removed from the MongoDB collections of unkept flavors. A "deleted" Redis event is also sent.

Before deduplication, there were 8898 duplicate products.
after opff: 8730
after opf: 7598
after obf: 6817
after off: 4686

4663 duplicate products

2024/10/28: 4595 duplicate products

I manually reviewed the top 1000 products (by scans on OFF) of the 4595 products. For the rest, we will keep the flavor with the most data.

Ran on all 4 flavors:
./scripts/migrations/2024_10_remove_duplicate_products_on_wrong_flavors.pl --flavor /home/off/20241030_duplicate_products_reviewed_top_1000.tsv

After that, ran the script again for the remaining products, using the flavor with the most data (and not a deleted product).

I had forgotten to check the obsolete flavors as well, modified the detection script to do that.

 ./scripts/migrations/2024_10_remove_duplicate_products_on_wrong_flavors.pl --flavor /home/off/20241115_duplicate_products.tsv 




