#!/bin/bash

# Don't forget chmod +x proplatform.sh

path="/home/off/mirabelle/"
db="off-stats.db"
year=`date +"%Y"`
month=`date +"%m"`
day=`date +"%d"`

# Total number of products sent via the pro platform in some countries at a certain day.
table="products_from_owners"

# Fill the countries for which we want stats
for country in at be ch de es fr ie it nl pl pt uk us
do
sleep 1
nb=`curl -s https://$country.openfoodfacts.org/owners?json=1 | jq "[.tags[].products] | add"`
echo        "insert into $table values ('$year','$month','$day','$country',$nb);"
sqlite3 $path$db "insert into $table values ('$year','$month','$day','$country',$nb);"
done

#sudo systemctl restart datasette.service