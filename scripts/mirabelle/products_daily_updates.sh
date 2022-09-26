#!/bin/bash
path=/home/off/mirabelle
cd $path

export PATH="/usr/local/bin:$PATH"
rm en.openfoodfacts.org.products.csv.bak products.db.bak products_new.db
old_csv=$(wc -c en.openfoodfacts.org.products.csv | awk '{print $1}')
old_csv_lines=$(wc -l en.openfoodfacts.org.products.csv | awk '{print $1}')
echo "Old CSV weights $old_csv bytes for $old_csv_lines lines"
read -p "Press [Enter] key to downloaf CSV..."

wget -c https://static.openfoodfacts.org/data/en.openfoodfacts.org.products.csv -O newdata.csv
new_csv=$(wc -c newdata.csv | awk '{print $1}')
new_csv_lines=$(wc -l newdata.csv | awk '{print $1}')
echo "New CSV weights $new_csv bytes for $new_csv_lines lines"

if [ "$new_csv" -ge "$old_csv" ]
then
  read -p "Press [Enter] key to create new db..."
  mv en.openfoodfacts.org.products.csv en.openfoodfacts.org.products.csv.bak
  mv newdata.csv en.openfoodfacts.org.products.csv
  echo `date`;
  # Create DB and import CSV data
  time sqlite3 products_new.db <<EOS
/* Optimisations. See: https://avi.im/blag/2021/fast-sqlite-inserts/ */;
PRAGMA journal_mode=OFF;
PRAGMA synchronous=0;
PRAGMA locking_mode=EXCLUSIVE;
PRAGMA temp_store=MEMORY;
PRAGMA page_size = 32768;
$(curl https://gist.githubusercontent.com/CharlesNepote/80fb813a416ad445fdd6e4738b4c8156/raw/5a45a89e77a017a27ae8c071aac9620b7f0d3779/create.sql)
.mode ascii
.separator "\t" "\n"
.import --skip 1 en.openfoodfacts.org.products.csv all
$(curl https://gist.githubusercontent.com/CharlesNepote/80fb813a416ad445fdd6e4738b4c8156/raw/032af70de631ff1c4dd09d55360f242949dcc24f/index.sql)
CREATE VIEW simplified AS select rowid, code, url, creator, created_datetime, last_modified_datetime, product_name, generic_name, quantity, packaging_en, packaging_text, brands, categories, categories_en, origins_en, manufacturing_places, manufacturing_places_tags, labels, labels_en, emb_codes, emb_codes_tags, first_packaging_code_geo, cities, cities_tags, purchase_places, stores, countries_en, ingredients_text, ingredients_tags, allergens_en, traces_en, serving_size, serving_quantity, no_nutriments, additives_n, additives, additives_en, nutriscore_score, nutriscore_grade, nova_group, pnns_groups_1, pnns_groups_2, food_groups_en, states_en, brand_owner, ecoscore_score, ecoscore_grade, main_category_en, image_url, image_ingredients_url, image_nutrition_url, [energy-kj_100g], [energy-kcal_100g], energy_100g, [energy-from-fat_100g], fat_100g, [saturated-fat_100g], carbohydrates_100g, sugars_100g, fiber_100g, proteins_100g, salt_100g, sodium_100g, alcohol_100g, [fruits-vegetables-nuts_100g], [fruits-vegetables-nuts-dried_100g], [fruits-vegetables-nuts-estimate_100g], [fruits-vegetables-nuts-estimate-from-ingredients_100g], [nutrition-score-fr_100g], [nutrition-score-uk_100g] from [all];
EOS
# real    2m2.761s
else
  echo "CSV error?"
fi

#read -p "Press [Enter] key to continue..."
rm en.openfoodfacts.org.products.csv.bak

# Converting empty to NULL for columns which are either FLOAT or INTEGER
time sqlite3 products_new.db ".schema all" | sed -nr 's/.*\[(.*)\] (INTEGER|FLOAT).*/\1/gp' | xargs -I % sqlite3 products_new.db -cmd "PRAGMA journal_mode=OFF;" "UPDATE [all] SET [%] = NULL WHERE [%] = '';"
mv products.db products.db.bak
mv products_new.db products.db
echo `date`;
sudo systemctl restart datasette.service

# TODO: Wait for 20s and reset nginx cache with curl or rm -rf /var/cache/
# https://docs.nginx.com/nginx/admin-guide/content-cache/content-caching/
sleep 20; echo "Waiting for 20s before clearing nginx cache..."
# Clear cache and restart nginx
sudo $path/clear_cache.sh "products"

# TODO: load pages frequently used
# curl ........;
