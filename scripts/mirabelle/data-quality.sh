#!/bin/bash

# Don't forget chmod +x proplatform.sh

# Usage: data-quality.sh target.db

path="/home/off/mirabelle/"
db=$1
year=`date +"%Y"`
month=`date +"%m"`
day=`date +"%d"`

function ifFailed {
    EXIT=$?
    if [[ $EXIT -ne 0 ]] ; then
       printf '%s\n' "$1" >&2 ## Send message to stderr.
       exit "${2-1}" ## Return a code specified by $2, or 1 by default.
    fi
}

# Test databases
NB_OF_PRODUCTS=$(sqlite3 products.db "select count(code) from [all];")
ifFailed "products.db: database error $?" "2" # Exit if the database is not reachable
[[ "${NB_OF_PRODUCTS}" -lt "2500000" ]] && { echo "products.db: ${NB_OF_PRODUCTS} products. Number of products is too low"; printf '%s\n' "$1" >&2; exit 4; };

# Build smaller database to speed-up queries
#sqlite3 tempo.db <<EOF
#ATTACH 'products.db' as products;
#CREATE TABLE [all] AS
#  SELECT code, countries_en, data_quality_errors_tags, last_image_datetime, main_category_en, ingredients_tags, states_tags, unique_scans_n, brands
#  FROM db2.t2 where data_quality_errors_tags != "";
#EOF

echo "Backup ${path}${db} to ${path}${db}-$(date -r ${path}${db} +'%Y-%m-%d-%H-%M-%S').db"
cp "${path}${db}" "${path}${db}-$(date -r ${path}${db} +'%Y-%m-%d-%H-%M-%S').db"
find ${path}${db}-20* -mtime +8 -delete # delete backups older than 8 days

# Total number of products sent via the pro platform in some countries at a certain day.
table="data_quality_stats"
sqlite3 ${path}${db} "CREATE TABLE IF NOT EXISTS data_quality_stats(year TEXT,month TEXT,day TEXT,country TEXT,property TEXT,value TEXT);"
declare -A cc
cc["ae"]="United Arab Emirates"
cc["ar"]="Argentina"
cc["at"]="Austria"
cc["au"]="Australia"
cc["be"]="Belgium"
cc["bg"]="Bulgaria"
cc["ca"]="Canada"
cc["ch"]="Switzerland"
cc["cl"]="Chile"
cc["co"]="Colombia"
cc["cz"]="Czech Republic"
cc["de"]="Germany"
cc["dk"]="Denmark"
cc["dz"]="Algeria"
cc["es"]="Spain"
cc["fi"]="Finland"
cc["fr"]="France"
cc["gr"]="Greece"
cc["hr"]="Croatia"
cc["hu"]="Hungary"
cc["ie"]="Ireland"
cc["it"]="Italy"
cc["in"]="India"
cc["jp"]="Japan"
cc["lt"]="Lithuania"
cc["lu"]="Luxembourg"
cc["lv"]="Latvia"
cc["ma"]="Morocco"
cc["mx"]="Mexico"
cc["nc"]="New Caledonia"
cc["nl"]="Netherlands"
cc["no"]="Norway"
cc["nz"]="New Zealand"
cc["pl"]="Poland"
cc["pr"]="Puerto Rico"
cc["pt"]="Portugal"
cc["re"]="Réunion"
cc["ro"]="Romania"
cc["rs"]="Serbia"
cc["ru"]="Russia"
cc["sa"]="Saudi Arabia"
cc["se"]="Sweden"
cc["sg"]="Singapore"
cc["th"]="Thailand"
cc["tn"]="Tunisia"
cc["tr"]="Turkey"
cc["uk"]="United Kingdom"
cc["us"]="United States"
cc["za"]="South Africa"


# Fill the countries for which we want stats
#for country in world at be ch de es fr ie it nl pl pt uk us
for country in world ae ar at au be bg ca ch cl co cz de dk es fi fr gr hr hu ie it in jp lt lu lv ma mx nc nl no nz pl pr pt re ro rs ru sa se sg th tn tr uk us za
do
#sleep 1
[[ $country != "world" ]] && country_condition=" and countries_en like '%${cc[$country]}%' " || country_condition=""
echo ""
echo "country_condition: ${country_condition}"
#nb=`curl -s https://$country.openfoodfacts.org/owners?json=1 | jq "[.tags[].products] | add"`
#echo        "insert into $table values ('$year','$month','$day','$country',$nb);"
#sqlite3 $path$db "insert into $table values ('$year','$month','$day','$country',$nb);"
sqlite3 ${path}${db} <<EOS
PRAGMA cache_size = 10000;
PRAGMA temp_store = 2; -- Use memory as temporary storage; does not seem to have any effect
pragma journal_mode = WAL; -- ?
ATTACH DATABASE 'products.db' AS products;
-- echoing each command
.echo on
-- launch explain query plan
--.eqp on
-- launch timer
.timer on
-- .expert
insert into ${table}
  SELECT
    "$year","$month","$day",'${country}',"total_nb_of_products",
    count(rowid) as value from products.[all]
    where true ${country_condition};
--
insert into ${table}
  SELECT
    "$year","$month","$day",'${country}',"products_with_errors",
    count(data_quality_errors_tags) as value from products.[all]
    where data_quality_errors_tags != "" ${country_condition};
--
insert into ${table}
  SELECT
    "$year","$month","$day",'${country}',"products_w_issues_but_no_image",
    count(data_quality_errors_tags) as products_w_issues_but_no_image from products.[all]
    where data_quality_errors_tags != "" and last_image_datetime == "" ${country_condition};
--
insert into ${table}
  SELECT
    "$year","$month","$day",'${country}',"products_wo_category",
    count(main_category_en) from products.[all]
    where main_category_en == "" ${country_condition};
--
insert into ${table}
  SELECT
    "$year","$month","$day",'${country}',"products_wo_ingredients",
    count(ingredients_tags) from products.[all]
    where ingredients_tags == "" ${country_condition};
--
insert into ${table} -- TODO: to be verified with nutrients' data
  SELECT
    "$year","$month","$day",'${country}',"products_wo_nutrition_facts",
    count(states_tags) from products.[all]
    where states_tags like "%nutrition-facts-to-be-completed%" ${country_condition};
--
insert into ${table} -- TODO: to be verified with packagings' data
  SELECT
    "$year","$month","$day",'${country}',"products_wo_packaging_data",
    count(states_tags) from products.[all]
    where states_tags like "%packaging-to-be-completed%" ${country_condition};
insert into ${table}
  SELECT
    "$year","$month","$day",'${country}',"scans_of_products_with_errors",
    sum(case when (data_quality_errors_tags != "" ${country_condition}) then unique_scans_n else 0 end) from products.[all];
insert into ${table}
  SELECT
    "$year","$month","$day",'${country}',"products_wo_brand",
    count(brands) from products.[all]
    where brands == "" ${country_condition};
EOS
echo "--------------------- end ${country}"
done
