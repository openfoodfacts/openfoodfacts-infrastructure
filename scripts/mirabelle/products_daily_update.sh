#!/bin/bash
path=/home/off/mirabelle
cd $path || { echo "$(date +'%Y-%m-%dT%H:%M:%S') - Can't cd ${path}"; exit 1; }
mode=""
file=""
stats=""
TODAY=$(date "+%Y-%m-%d")
#csv="en.openfoodfacts.org.products.csv"
url="https://static.openfoodfacts.org/data/en.openfoodfacts.org.products.csv"


# Read commanline arguments. Try -h to get usage.
usage() { echo "$0 usage:" && grep " .)\ #" "$0"; exit 0; }
while getopts ":hf:in" arg; do
  case $arg in
    f) # Specify a filename.
      file=${OPTARG}
      echo "$(date +'%Y-%m-%dT%H:%M:%S') - File is ${file}"
      ;;
    i) # Specify interactive mode.
      mode="i"
      ;;
    n) # don't run stats.
      stats="s"
      ;;
    h | *) # Display help.
      usage
      exit 0
      ;;
  esac
done


export PATH="/usr/local/bin:$PATH"

[[ $mode == "i" ]] && read -p "Press [Enter] key to begin the script in interactive mode."


# Display information on previous CSV
old_csv=$(wc -c en.openfoodfacts.org.products.csv | awk '{print $1}')
old_csv_lines=$(wc -l en.openfoodfacts.org.products.csv | awk '{print $1}')
echo "$(date +'%Y-%m-%dT%H:%M:%S') - Old CSV weights $old_csv bytes for $old_csv_lines lines"


# Choose CSV depending on the command line -f argument.
if [[ "${file}" == "" ]]; then
  # Don't download the file again if it has already been done today.
  if [[ $(date -r en.openfoodfacts.org.products.csv "+%Y-%m-%d") == "${TODAY}" ]]; then
    echo "$(date +'%Y-%m-%dT%H:%M:%S') - CSV file has already been downloaded today. Copying it..."
    cp en.openfoodfacts.org.products.csv newdata.csv
  else # Else download the file
    [[ "$mode" == "i" ]] && read -p "Press [Enter] key to download CSV..."
    echo "$(date +'%Y-%m-%dT%H:%M:%S') - Downloading CSV..."

    # Get the date of the file to be downloaded. Retry 24 times until the date is not corresponding to today.
    export_date=$(curl -L -s -v -X HEAD https://static.openfoodfacts.org/data/en.openfoodfacts.org.products.csv 2>&1 | grep -ioP '.*Last-Modified: \K(.*)$' | tr -d '\r')
    # We don't use .gz file because it is generated dozens of minutes later
    counter=1
    # Trying to download the file. Attention: sometimes curl command does not return anything.
    while [[ ${export_date} == "" || "$(date -d "${export_date}" +%Y-%m-%d)" < "${TODAY}" ]]; do
        # Exit after 60 tries.
        [[ "${counter}" -gt 60 ]] && { echo "$(date +'%Y-%m-%dT%H:%M:%S') - Retried ${counter} times, but en.openfoodfacts.org.products.csv is from ${export_date} and not ${TODAY}. Now exit..." | tee >(cat >&2); exit 1; }
        ((counter++))
        echo "$(date +'%Y-%m-%dT%H:%M:%S') - CSV export is from ${export_date} and not today (${TODAY}). Retrying ${counter} in 10 minutes"
        sleep 10m
        export_date=$(curl -L -s -v -X HEAD https://static.openfoodfacts.org/data/en.openfoodfacts.org.products.csv 2>&1 | grep -ioP '.*Last-Modified: \K(.*)$' | tr -d '\r')
    done

    echo "$(date +'%Y-%m-%dT%H:%M:%S') - Remote CSV is from ${export_date}. Downloading CSV..."
    #wget -O newdata.csv \        # name of the ouput file
    #     --quiet \               # Turn off Wget's output.
    #     --server-response \     # Print the headers sent by HTTP servers and responses sent by FTP servers.
    #     --continue \            # Compression does not work with --continue or --start-pos, they will be disabled.
    #     https://static.openfoodfacts.org/data/en.openfoodfacts.org.products.csv
    wget -O newdata.csv \
         --quiet \
         \ #--server-response \
         --compression=gzip \
         \ #--header="accept-encoding: gzip" \
         https://static.openfoodfacts.org/data/en.openfoodfacts.org.products.csv
    echo -e "ls -la newdata.csv\n$(ls -la newdata.csv)\n"
    # compare local and remote size to be sure download is ok
    #source_size=$(wget --spider "${url}" 2>&1 | awk '/Length/ {print $2}')
    #source_size=$(curl -s -v -X HEAD "${url}" 2>&1 | grep -ioP '.*content-length: \K(.*)$' | tr -d '\r')
    #downloaded_size=$(wc -c < "newdata.csv")
    #[[ ${source_size} -ne ${downloaded_size} ]] && { echo "Source size (${source_size}) is different from downloaded file size (${downloaded_size})..."; exit 1; } \
    #    || echo "Source size (${source_size}) is equal to downloaded file size (${downloaded_size})..."
  fi
else
  [[ $mode == "i" ]] && read -p "Press [Enter] key to use ${file} as source of the new DB."
  # Use -f filename as source file. Exit if the file can't be copied.
  echo "$(date +'%Y-%m-%dT%H:%M:%S') - Use -f filename (${file}) as source file."
  cp "${file}" newdata.csv || { echo "$(date +'%Y-%m-%dT%H:%M:%S') - cp error"; exit 1; }
fi


# TODO: verify number of fields is not different from current database
# nb_of_fields=$(head -n 1 newdata.csv | tr "\t" "\n" | wc -l)

# Display information on source CSV
[[ $mode == "i" ]] && read -p "Press [Enter] key to compare CSV from today and yesterday..."
new_csv=$(wc -c newdata.csv | awk '{print $1}')
new_csv_lines=$(wc -l newdata.csv | awk '{print $1}')
echo "$(date +'%Y-%m-%dT%H:%M:%S') - New CSV weights $new_csv bytes for $new_csv_lines lines"
echo "$(date +'%Y-%m-%dT%H:%M:%S') - Old CSV size $old_csv_lines"


# Create a temporary DB if today's CSV is bigger than yesterday
# TODO: better test new CSV (find newest product?)
if (( "$new_csv_lines" > "$old_csv_lines"-25000 )); then
  [[ "$mode" == "i" ]] && read -p "Press [Enter] key to create new db..."
  mv -f en.openfoodfacts.org.products.csv en.openfoodfacts.org.products.csv.bak
  mv newdata.csv en.openfoodfacts.org.products.csv
  echo "$(date +'%Y-%m-%dT%H:%M:%S') - Creating new DB..."
  # Create DB and import CSV data
  [[ -f "products_new.db" ]] && rm products_new.db # Delete the file before or data will be added to the existing one.
  sqlite3 products_new.db <<EOS
/* Optimisations. See: https://avi.im/blag/2021/fast-sqlite-inserts/ */;
PRAGMA journal_mode=OFF;
PRAGMA synchronous=0;
PRAGMA locking_mode=EXCLUSIVE;
PRAGMA temp_store=MEMORY;
PRAGMA page_size = 32768;
$(cat products.schema)
.mode ascii
.separator "\t" "\n"
.import --skip 1 en.openfoodfacts.org.products.csv all
SELECT strftime('%Y-%m-%dT%H:%M:%S', 'now') || " - Creating index...";
CREATE INDEX ["all_code"] ON [all]("code");
CREATE INDEX ["all_creator"] ON [all]("creator");
CREATE INDEX ["all_created_datetime"] ON [all]("created_datetime");
CREATE INDEX ["all_last_modified_datetime"] ON [all]("last_modified_datetime");
CREATE INDEX ["all_last_modified_by"] ON [all]("last_modified_by");
CREATE INDEX ["all_countries_en"] ON [all]("countries_en");
CREATE INDEX ["all_ingredients_tags"] ON [all]("ingredients_tags");
CREATE INDEX ["all_brands"] ON [all]("brands");
CREATE INDEX ["all_main_category_en"] ON [all]("main_category_en");
CREATE INDEX ["all_nutriscore_grade"] ON [all]("nutriscore_grade");
CREATE INDEX ["all_nova_group"] ON [all]("nova_group");
CREATE INDEX ["all_states_tags"] ON [all]("states_tags");
CREATE INDEX ["all_ecoscore_grade"] ON [all]("ecoscore_grade");
CREATE INDEX ["all_data_quality_errors_tags"] ON [all]("data_quality_errors_tags");
CREATE INDEX ["all_unique_scans_n"] ON [all]("unique_scans_n");
CREATE INDEX ["all_popularity_tags"] ON [all]("popularity_tags");
CREATE INDEX ["all_completeness"] ON [all]("completeness");
CREATE INDEX ["all_last_image_datetime"] ON [all]("last_image_datetime");
CREATE INDEX ["all_no_nutrition_data"] ON [all]("no_nutrition_data");
CREATE INDEX ["all_energy_100g"] ON [all]("energy_100g");
CREATE INDEX ["all_fat_100g"] ON [all]("fat_100g");
CREATE INDEX ["all_saturated-fat_100g"] ON [all]("saturated-fat_100g");
CREATE INDEX ["all_carbohydrates_100g"] ON [all]("carbohydrates_100g");
CREATE INDEX ["all_proteins"] ON [all]("proteins_100g");
CREATE VIEW simplified AS select rowid, code, url, creator, created_datetime, last_modified_datetime, last_modified_by,
  product_name, generic_name, quantity, packaging_en, packaging_text, brands, categories, categories_en,
  origins_en, manufacturing_places, manufacturing_places_tags, labels, labels_en, emb_codes, emb_codes_tags,
  first_packaging_code_geo, cities, cities_tags, purchase_places, stores, countries_en, ingredients_text,
  ingredients_tags, allergens_en, traces_en, serving_size, serving_quantity, no_nutrition_data, additives_n,
  additives, additives_en, nutriscore_score, nutriscore_grade, nova_group, pnns_groups_1, pnns_groups_2,
  food_groups_en, states_en, brand_owner, ecoscore_score, ecoscore_grade, main_category_en, image_url,
  image_ingredients_url, image_nutrition_url, [energy-kj_100g], [energy-kcal_100g], energy_100g,
  [energy-from-fat_100g], fat_100g, [saturated-fat_100g], carbohydrates_100g, sugars_100g, fiber_100g,
  proteins_100g, salt_100g, sodium_100g, alcohol_100g, [fruits-vegetables-nuts_100g], [fruits-vegetables-nuts-dried_100g],
  [fruits-vegetables-nuts-estimate_100g], [fruits-vegetables-nuts-estimate-from-ingredients_100g],
  [nutrition-score-fr_100g], [nutrition-score-uk_100g] from [all];
EOS
# real    3m2.761s
else
  echo "$(date +'%Y-%m-%dT%H:%M:%S') - CSV error? - Exiting..."
  exit 1
fi


# https://www.sqlite.org/forum/info/6351a2cba50fc0aa
# The import previously made by the .import command does not manage empty values, even if we declare DEFAULT NULL
# for each integer and each float. Not having null is annoying for sorting or comparing values.
# So we have to deal with this manually.
# There's a proposed change to allow null values on csv import: https://sqlite.org/forum/forumpost/35dea9db69
# See also: https://sqlite.org/forum/forumpost/6351a2cba50fc0aa

# Converting empty to NULL for columns which are either FLOAT or INTEGER
echo "$(date +'%Y-%m-%dT%H:%M:%S') - Converting empty to NULL"
$path/empty2null.sh products_new.db
#sqlite3 products_new.db ".schema all" | \
#  sed -nr 's/.*\[(.*)\] (INTEGER|FLOAT).*/\1/gp' | \
#  xargs -I % sqlite3 products_new.db -cmd \
#    "SELECT 'Convert empty to NULL for [%]';" \
#    "PRAGMA journal_mode=OFF;" \
#    "PRAGMA synchronous=0;" \
#    "PRAGMA locking_mode=EXCLUSIVE;" \
#    "PRAGMA temp_store=MEMORY;" \
#    "PRAGMA page_size = 32768;" \
#    "UPDATE [all] SET [%] = NULL WHERE [%] = '';"
printf "\n\n\n"


# If the new DB contains less than 2,500,000 products, there is probably an issue => exit
TODAY_DB=$(sqlite3 products_new.db "select count(code) from [all];")
[[ ${TODAY_DB} -lt 2500000 ]] && { echo "$(date +'%Y-%m-%dT%H:%M:%S') - DB issue"; exit 1; }


# Backup the old DB and replace it by the new one
echo "$(date +'%Y-%m-%dT%H:%M:%S') - Backup the old DB and replace it by the new one"
mv products.db previous.db
mv products_new.db products.db
printf "\n\n"


# Launch script to build data quality stats.
[[ ${stats} != "s" ]] && echo "$(date +'%Y-%m-%dT%H:%M:%S') - Build data quality stats" || echo "$(date +'%Y-%m-%dT%H:%M:%S') - Don't build data quality stats"
[[ ${stats} != "s" ]] && $path/data-quality.sh off-stats.db


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


echo -e "$(date +'%Y-%m-%dT%H:%M:%S') - END of script\n"
