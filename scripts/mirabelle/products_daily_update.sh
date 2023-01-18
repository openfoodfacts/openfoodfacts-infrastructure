#!/bin/bash
path=/home/off/mirabelle
cd $path
mode=""
file=""


# Read commandline arguments. Try -h to get usage.
usage() { echo "$0 usage:" && grep " .)\ #" $0; exit 0; }
while getopts ":hf:i" arg; do
  case $arg in
    f) # Specify a filename.
      file=${OPTARG}
      echo "$(date +'%Y-%m-%dT%H:%M:%S') - File is ${file}"
      ;;
    i) # Specify interactive mode.
      mode="i"
      ;;
    h | *) # Display help.
      usage
      exit 0
      ;;
  esac
done


TODAY=`date "+%Y-%m-%d"`
export PATH="/usr/local/bin:$PATH"

[[ $mode == "i" ]] && read -p "Press [Enter] key to begin the script in interactive mode."


# Display information on previous CSV
old_csv=$(wc -c en.openfoodfacts.org.products.csv | awk '{print $1}')
old_csv_lines=$(wc -l en.openfoodfacts.org.products.csv | awk '{print $1}')
echo "$(date +'%Y-%m-%dT%H:%M:%S') - Old CSV weights $old_csv bytes for $old_csv_lines lines"


# Choose CSV depending on the command line -f argument.
if [[ ${file} == "" ]]; then
  if [[ `date -r en.openfoodfacts.org.products.csv "+%Y-%m-%d"` == ${TODAY} ]]; then
    echo "$(date +'%Y-%m-%dT%H:%M:%S') - CSV file has already been downloaded today. Copying it..."
    cp en.openfoodfacts.org.products.csv newdata.csv
  else
    [[ $mode == "i" ]] && read -p "Press [Enter] key to download CSV..."
    echo "$(date +'%Y-%m-%dT%H:%M:%S') - Downloading CSV..."
    wget -c https://static.openfoodfacts.org/data/en.openfoodfacts.org.products.csv -O newdata.csv
    [[ $? -ne 0 ]] && { echo "Download failed, error $?"; exit 1; }
    printf "ls\n$(ls -la newdata.csv)\n\n"
  fi
else
  [[ $mode == "i" ]] && read -p "Press [Enter] key to use ${file} as source of the new DB."
  # Use -f filename as source file. Exit if the file can't be copied.
  echo "$(date +'%Y-%m-%dT%H:%M:%S') - Use -f filename (${file}) as source file."
  cp ${file} newdata.csv || { echo "$(date +'%Y-%m-%dT%H:%M:%S') - cp error"; exit 1; }
fi


# Display information on source CSV
[[ $mode == "i" ]] && read -p "Press [Enter] key to compare CSV from today and yesterday..."
new_csv=$(wc -c newdata.csv | awk '{print $1}')
new_csv_lines=$(wc -l newdata.csv | awk '{print $1}')
echo "$(date +'%Y-%m-%dT%H:%M:%S') - New CSV weights $new_csv bytes for $new_csv_lines lines"


# Create a temporary DB if today's CSV is bigger than yesterday
if [[ "$new_csv" -ge "$old_csv" ]]; then
  [[ $mode == "i" ]] && read -p "Press [Enter] key to create new db..."
  mv -f en.openfoodfacts.org.products.csv en.openfoodfacts.org.products.csv.bak
  mv newdata.csv en.openfoodfacts.org.products.csv
  echo "$(date +'%Y-%m-%dT%H:%M:%S') - Creating new DB..."
  # Create DB and import CSV data
  time sqlite3 products_new.db <<EOS
/* Optimisations. See: https://avi.im/blag/2021/fast-sqlite-inserts/ */;
PRAGMA journal_mode=OFF;
PRAGMA synchronous=0;
PRAGMA locking_mode=EXCLUSIVE;
PRAGMA temp_store=MEMORY;
PRAGMA page_size = 32768;
$(curl https://gist.githubusercontent.com/CharlesNepote/80fb813a416ad445fdd6e4738b4c8156/raw/3b029183cb28dd410f0ef8748f06c9174b2518a8/create_from_new_csv.sql)
.mode ascii
.separator "\t" "\n"
.import --skip 1 en.openfoodfacts.org.products.csv all
$(curl https://gist.githubusercontent.com/CharlesNepote/80fb813a416ad445fdd6e4738b4c8156/raw/ff008e945ebb1379d713097358fd1284d4b71831/index_new_csv.sql)
CREATE VIEW simplified AS select rowid, code, url, creator, created_datetime, last_modified_datetime, product_name, generic_name, quantity, packaging_en, packaging_text, brands, categories, categories_en, origins_en, manufacturing_places, manufacturing_places_tags, labels, labels_en, emb_codes, emb_codes_tags, first_packaging_code_geo, cities, cities_tags, purchase_places, stores, countries_en, ingredients_text, ingredients_tags, allergens_en, traces_en, serving_size, serving_quantity, no_nutriments, additives_n, additives, additives_en, nutriscore_score, nutriscore_grade, nova_group, pnns_groups_1, pnns_groups_2, food_groups_en, states_en, brand_owner, ecoscore_score, ecoscore_grade, main_category_en, image_url, image_ingredients_url, image_nutrition_url, [energy-kj_100g], [energy-kcal_100g], energy_100g, [energy-from-fat_100g], fat_100g, [saturated-fat_100g], carbohydrates_100g, sugars_100g, fiber_100g, proteins_100g, salt_100g, sodium_100g, alcohol_100g, [fruits-vegetables-nuts_100g], [fruits-vegetables-nuts-dried_100g], [fruits-vegetables-nuts-estimate_100g], [fruits-vegetables-nuts-estimate-from-ingredients_100g], [nutrition-score-fr_100g], [nutrition-score-uk_100g] from [all];
EOS
# real    3m2.761s
else
  echo "$(date +'%Y-%m-%dT%H:%M:%S') - CSV error?"
  exit 1
fi


# Converting empty to NULL for columns which are either FLOAT or INTEGER
echo "$(date +'%Y-%m-%dT%H:%M:%S') - Converting empty to NULL"
time sqlite3 products_new.db ".schema all" | \
  sed -nr 's/.*\[(.*)\] (INTEGER|FLOAT).*/\1/gp' | \
  xargs -I % sqlite3 products_new.db -cmd \
    "SELECT 'Convert empty to NULL for [%]';" \
    "PRAGMA journal_mode=OFF;" \
    "PRAGMA synchronous=0;" \
    "PRAGMA locking_mode=EXCLUSIVE;" \
    "PRAGMA temp_store=MEMORY;" \
    "PRAGMA page_size = 32768;" \
    "UPDATE [all] SET [%] = NULL WHERE [%] = '';"


# If the new DB contains less than 2,500,000 products, there is probably an issue => exit
TODAY_DB=$(sqlite3 products_new.db "select count(code) from [all];")
[[ ${TODAY_DB} -lt 2500000 ]] && { echo "$(date +'%Y-%m-%dT%H:%M:%S') - DB issue"; exit 1; }


# Backup the old DB and replace it by the new one
echo "$(date +'%Y-%m-%dT%H:%M:%S')  - Backup the old DB and replace it by the new one"
mv products.db previous.db
mv products_new.db products.db


# Launch script to build data quality stats.
time $path/data-quality.sh


# Restart mirabelle server
echo "$(date +'%Y-%m-%dT%H:%M:%S') - Restarting datasette..."
sudo systemctl restart datasette.service


# Wait for 20s and reset nginx cache with curl or rm -rf /var/cache/
# https://docs.nginx.com/nginx/admin-guide/content-cache/content-caching/
echo "$(date +'%Y-%m-%dT%H:%M:%S') - Waiting for 20s before clearing nginx cache..."; sleep 20
# Clear cache and restart nginx
sudo $path/clear_cache.sh "products"

# TODO: load pages frequently used
# curl ........;


echo "$(date +'%Y-%m-%dT%H:%M:%S') - END of script"
