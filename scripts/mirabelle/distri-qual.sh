#!/bin/bash


# ---- TODO
# * Features for end users:
#   * link to help page: forum? wiki?
#   * 3 more products for hardcore fixers
#   * data quality news section
#     or just a colored line at the begining of the email; "Very short message: great job old chaps! (This line will be dedicated to short messages.)"
#   * add an anchor to the edit link to go directly to the nutrition table?
#     (CON: some issues are not related to nutrition table)

# * Script usage:
#   * separate update and emailing: --update-only
#   * send a test email but without updating anything: --send_test charles@openfoodfacts.org
#   * send new email for one people only: --send-new-user bibi
#   * option with getops for the mode

# * group year, month, day in http://mirabelle.openfoodfacts.org/off-stats
#   * new data quality issues: see: http://mirabelle.openfoodfacts.org/off-stats/aggregated_stats
# * after a delay (1 month?) create a new entry for old issues that has been sent but not fixed


# ---- Requirements
# * sqlite (standard Debian package)
# * sendmail command (via postfix or another smtp client)
# * data come from mirabelle.openfoodfacts.org

printf "${0} launched $(date +'%Y-%m-%dT%H:%M:%S')\n\n"
env
echo "---------------------------"
cd /home/off/mirabelle
PATH=/sbin:/bin:/usr/sbin:/usr/bin
TODAY=`date "+%Y-%m-%d"`



# ---- Setup
<<comments
sqlite3 dq-members.db < <( cat <<EOF
CREATE TABLE IF NOT EXISTS members (
       id INTEGER PRIMARY KEY,
       off_username TEXT NOT NULL,
       email TEXT NOT NULL);
INSERT INTO members (off_username,email) VALUES ("charlesnepote","charles@openfoodfacts.org");
EOF
comments



# 1. ---- settings

# mode: "test" => don't send
#        "i"   => interactive
mode=""

# Goal: percent of products with a data quality error; see: https://world.openfoodfacts.org/data-quality-errors
goalInPercent=0.9; # TODO: use it when more than 10 members

# Edit link
editLink="https://world.openfoodfacts.org/cgi/product.pl?type=edit&code="

function ifFailed {
    EXIT=$?
    if [[ $EXIT -ne 0 ]] ; then
       printf '%s\n' "$1" >&2 ## Send message to stderr.
       exit "${2-1}" ## Return a code specified by $2, or 1 by default.
    fi
}



# 2. ---- read useful data; exit if the databases are not reachable or not up to date
echo "Reading usefull data..."

# total nb of products
totalNbOfProducts=$(sqlite3 products.db "select count(rowid) from [all];")
echo "Total nb of products: ${totalNbOfProducts}"

# nb of products with issues (minus non solvable?) and percentage
nbOfProductsWithAnIssue=$(sqlite3 products.db "select count(data_quality_errors_tags) from [all] where data_quality_errors_tags != '';")
ifFailed "products.db: database error $?" "2" # Exit if the database is not reachable

percentOfProductsWithAnIssue=`printf %.2f "$(( ${nbOfProductsWithAnIssue} *10000 / ${totalNbOfProducts} ))e-2"`
echo "Nb of products with issues: ${nbOfProductsWithAnIssue} representing ${percentOfProductsWithAnIssue} percents"

# nb of participants
nbOfContributors=$(sqlite3 dq-members.db "select count(id) from [members];")
echo "Number of contributors: ${nbOfContributors}"
ifFailed "dq-members.db: database error $?" "2" # Exit if the database is not reachable

lastProductEditedOn=$(sqlite3 products.db "select last_modified_datetime from [all] order by last_modified_datetime desc limit 1;")
echo "Last product edited on: ${lastProductEditedOn}" # 2023-01-16T02:39:22Z
# Exit if the database is not up to date
[[ "${lastProductEditedOn}" == "${TODAY}"* ]] || { echo "DB is not up to date"; exit 1; }

nbOfProductsFixedTwoDaysAgo=$(sqlite3 dq-issues.db "select count(*) from distrib where fixed_date == DATE('now','-1 day');")
echo "Nb of products fixed two days ago: ${nbOfProductsFixedTwoDaysAgo}"
ifFailed "dq-issues.db: database error $?" "2" # Exit if the database is not reachable

lastProductEntriedOn=$(sqlite3 dq-issues.db "select entry_date from distrib order by entry_date desc limit 1;")
echo "lastProductEntriedOn: ${lastProductEntriedOn}"

lastProductSentOn=$(sqlite3 dq-issues.db "select sent_date from distrib order by sent_date desc limit 1;")
echo "lastProductSentOn: ${lastProductSentOn}"

printf "\n\n"



# 2b. ---- backup before updating
dbLastModifiedOn=$(date -r dq-issues.db +"%Y-%m-%d-%H-%M-%S")
echo "Backup dq-issues.db to dq-issues-${dbLastModifiedOn}.db"
cp "dq-issues.db" "dq-issues-${dbLastModifiedOn}.db" # backup before update
find dq-issues-20* -mtime +5 -delete # delete backups older than 5 days
cp "dq-members.db" "dq-members-$(date -r dq-members.db +'%Y-%m-%d-%H-%M-%S').db"
find dq-members-20* -mtime +10 -delete # delete backups older than 5 days
printf "\n\n"



# 3. ---- Add new products (dq-issues.db)

# setup
<<comments

id|code  |data_quality_errors |entry_date  |sent_date  |sent_to_user  |fixed_date
1 |0     |xxx                 |2022-11-01  |           |              |
2 |1     |xxx                 |2022-11-01  |2022-11-05 |charlesnepote |
3 |2     |zzz                 |2022-11-02  |2022-11-05 |charlesnepote |2022-11-10
4 |2     |zzz                 |2022-11-12  |           |              |
5 |3     |zzz                 |2022-11-02  |2022-11-05 |charlesnepote |2022-11-10
6 |3     |zzz                 |2022-11-12  |2022-11-13 |charlesnepote |2022-11-15

sqlite3 dq-issues.db < dq-issues-schema.sql

# Then firstly populate the db with:
sqlite3 dq-issues.db < <( cat <<EOF
ATTACH DATABASE 'products.db' AS products;
insert into distrib (code, data_quality_errors, entry_date)
  select code, data_quality_errors_tags, DATE('now') from products.[all] as p
  where p.data_quality_errors_tags != "" and
        (NOT EXISTS(SELECT * FROM distrib where code = p.code));
select count(id) from distrib;
EOF
)
comments

# Add new products into distrib db
echo "Adding new products..."
[[ ${mode} == "i" ]] && read -p "Press [Enter] key to add new products and continue..."
[[ ${mode} != "test" ]] && sqlite3 dq-issues.db < <( cat <<EOF
ATTACH DATABASE 'products.db' AS products;
insert into distrib (code, data_quality_errors, entry_date)
  select code, data_quality_errors_tags, DATE('now') from products.[all] as p
  where
    p.data_quality_errors_tags != "" and
    (
      -- either the products does not exist at all in distrib table
      (NOT EXISTS
        (SELECT * FROM distrib where code = p.code)
      ) or
      -- either the product exists but its last entries has been fixed
      (EXISTS
        (SELECT * FROM distrib where code = p.code and fixed_date != ""
         order by entry_date desc limit 1)
      )
    );
select changes();
EOF
)



# 4. ---- Update existing products
# For each product check if it is still an error; add date of correction (fixed date)
<<comments
sqlite3 dq-issues.db < <( cat <<EOF

ATTACH DATABASE 'products.db' AS products;

-- Find products in dq-issues that are not in products.db (products deleted from OFF database)
select distrib.code, distrib.data_quality_errors, entry_date, sent_date, sent_to_user, fixed_date from distrib
  where fixed_date == "" and distrib.code not in (select code from products.[all]);

-- Find products in products.db which are in distrib but not having a data-quality-issue in products.db
select distrib.code, distrib.data_quality_errors, entry_date, sent_date, sent_to_user, fixed_date --, products.[all].data_quality_errors_tags
  from distrib --, products.[all] as p
  where
    distrib.fixed_date == ""
    and distrib.code in 
      (select p.code from products.[all] as p 
         where 
           p.data_quality_errors_tags == ""
         -- group by p.code
         --order by last_modified_datetime
         --limit 1
      );
    -- exclude duplicates in products.db

EOF
)
comments

# Update products
echo "Updating existing products..."
[[ ${mode} == "i" ]] && read -p "Press [Enter] key to update products and continue..."
[[ ${mode} != "test" ]] && sqlite3 dq-issues.db < <( cat <<EOF
ATTACH DATABASE 'products.db' AS products;
-- Mark products as fixed, from dq-issues that are not in products.db (products deleted from OFF database)
update distrib
  set fixed_date = DATE('now')
    where fixed_date == "" 
      and distrib.code not in (select code from products.[all]);
select changes(); -- returns nb of database rows that were changed by the most recently completed INSERT, DELETE, or UPDATE statement

-- Mark products as fixed, from dq-issues that do not have any quality issue in products.db
update distrib
  set fixed_date = DATE('now')
    where fixed_date == "" 
      and distrib.code in (select code from products.[all] as p where p.data_quality_errors_tags == "")
  ;
select changes();
EOF
)

nbOfNewProductsWithIssues=$(sqlite3 dq-issues.db "select count(*) from distrib where entry_date == DATE('now');")
echo "nbOfNewProductsWithIssues: ${nbOfNewProductsWithIssues}"

nbOfProductsFixedYesterday=$(sqlite3 dq-issues.db "select count(*) from distrib where fixed_date == DATE('now');")
#select * from distrib where fixed_date == DATE('now') order by fixed_date desc limit 7;
echo "nbOfProductsFixedYesterday: ${nbOfProductsFixedYesterday}"

averageNbOfProductsFixedPerDay=$(sqlite3 dq-issues.db "select (count(distinct(code))/14) from distrib where fixed_date >= DATE('now','-14 day');")
echo "averageNbOfProductsFixedPerDay: ${averageNbOfProductsFixedPerDay}"

averageNbOfNewProductsInErrorPerDay=$(sqlite3 dq-issues.db "select (count(distinct(code))/14) from distrib where entry_date >= DATE('now','-14 day');")
echo "averageNbOfNewProductsInErrorPerDay: ${averageNbOfNewProductsInErrorPerDay}"

averageNetProductsFixedPerDay=$((${averageNbOfProductsFixedPerDay}-${averageNbOfNewProductsInErrorPerDay}))
echo "averageNetProductsFixedPerDay: ${averageNetProductsFixedPerDay}"

# Build leader board
leaderBoard=$(sqlite3 dq-issues.db <<EOF
.mode html
-- .headers on
select sent_to_user as open_food_facts_user
     , count(distinct code) as nb_of_products_fixed
from distrib
where fixed_date != ""
  and date(fixed_date) >= date('now', '-5 day')
  and sent_to_user != ""
group by sent_to_user
order by open_food_facts_user
limit 50;
EOF
)
echo "leaderBoard: ${leaderBoard}"


# Compute number of days to reach the goalInPercent
# 6.0 - 5.5 = 0.5
# 2,600,000 * 0.005 = 13000 products
# 13000 / (moyenne quotidienne sur 30 jours 100) = 4.2 months
#        - (1.9% de progression du nombre total de produits par mois * 4) (mais ca ne joue pas beaucoup)
# or
# Compute average net product fixed per day: ~150
# and divide 13000/150 = 86 jours = 13 semaines




# 4. Iterate over members
#
<<comments
1|charlesnepote|charles@openfoodfacts.org
2|charlesnepote|charles@nepote.org
comments

[[ ${mode} == "i" ]] && read -p "Press [Enter] key to iterate over members..."
readarray contributors < <( sqlite3 dq-members.db "SELECT * FROM members;" )
for row in "${contributors[@]}"; do
    #echo "$row"
    readarray -t -d '|' user < <( printf '%s' "$row" )
    email=${user[2]}

#  * take 3 products with the following characteristics:
#    * not already sent or sent more than x months ago
#    * is often scaned (popularity)
#    * has at least one photo (has as many photos as possible)
#    * has a nutriscore computed?
#    * at least one product is in the top 10000?
#  * send email
#  * mark products as sent to xxx on yyy date

readarray products < <( sqlite3 dq-issues.db <<EOF
ATTACH DATABASE 'products.db' AS products;
SELECT distrib.id, p.code, CAST(p.unique_scans_n as INTEGER) as pop, p.data_quality_errors_tags
 FROM products.[all] as p
  inner join distrib on p.code = distrib.code
  where
    (distrib.sent_date == "" or distrib.sent_date IS NULL)
    and (distrib.fixed_date == "" or distrib.fixed_date IS NULL)
    -- and (p.last_image_t != "") -- or p.last_image_t IS NOT NULL)  -- there is an image
    and (p.image_nutrition_url != "")
    and (p.image_ingredients_url != "")
    and (p.owner not like "%org-nestle%")  -- nestle is sending wrong data every day
  order by pop DESC
  limit 3
;
EOF
)
echo "--"

# 4.1 Build product list
<<comments
|code  |data_quality_errors |entry_date  |sent_date  |sent_to_user  |fixed_date
|0     |xxx                 |2022-11-01  |           |              |
|1     |xxx                 |2022-11-01  |2022-11-05 |charlesnepote |
|2     |zzz                 |2022-11-02  |2022-11-05 |charlesnepote |2022-11-10
comments

products_list=""
for row in "${products[@]}"; do
  echo ${row}
  readarray -t -d '|' arrayline < <( printf '%s' "$row" )
  products_list+='<li>'
  products_list+='<a href="'${editLink}${arrayline[1]}'">'${arrayline[1]}'</a> '
  products_list+='('${arrayline[2]}' scans)<br/>'$'\n  '
  products_list+=`echo ${arrayline[3]} | sed 's/^en://g; s/,en:/, /g; s/-/ /g'`
  products_list+='</li>'$'\n'

  # Change state of the product: it has been sent (dq-issues database)
  [[ ${mode} != "test" ]] && sqlite3 dq-issues.db <<EOF
  UPDATE distrib
  SET sent_date = DATE('now'), sent_to_user = "${user[1]}"
  WHERE id == "${arrayline[0]}";
EOF
done

echo $'\n'"Sending email --------------------------------------------------------------------------------------"

# 4.2 Send email
emailToSend=$(cat <<EOF
From: Data Quality Daily<contact@openfoodfacts.org>
To: ${email}
Subject: Open Food Facts data-quality daily
MIME-Version: 1.0
Content-type: text/html; charset=UTF-8
<html>
<body>
<p>Hello fellow contributor!</p>

<p>${nbOfContributors} awesome contributors are currently receiving such an email.</p>

<h3 style="margin-bottom: 1px; padding-bottom: 3px;">Below are <strong>your</strong> 3 products to fix:</h3>
<ul style="padding-left: 20px;">
${products_list}
</ul>

<p><strong>Having a little more time?</strong> Check randomized data quality errors list:<br/>
<a href="https://link.openfoodfacts.org/data-quality-errors-random">
https://link.openfoodfacts.org/data-quality-errors-random</a>
</p>
<div style="background-color: lightgrey; padding: 10px; width: auto;">
<p>Hard to fix some products? Write us <a href="mailto:contact@openfoodfacts.org">an email</a>,
   or join the <a href="https://slack.openfoodfacts.org">#quality-data group on Slack</a>.</p>
</div>

<h3 style="margin-bottom: 1px; padding-bottom: 3px;">Daily stats</h3>
All data and stats in this email are made from the last CSV export, where last product was added on ${lastProductEditedOn}.
<ul style="padding-left: 20px;">
<li>Total nb of products: $(echo ${totalNbOfProducts} | sed ':a;s/\B[0-9]\{3\}\>/,&/;ta')</li>
<li>Nb of products with issues: $(echo ${nbOfProductsWithAnIssue}| sed ':a;s/\B[0-9]\{3\}\>/,&/;ta')
    representing ${percentOfProductsWithAnIssue} percents</li>
<li>Nb of products fixed yesterday: ${nbOfProductsFixedYesterday}</li>
</ul>


<h3 style="margin-bottom: 1px; padding-bottom: 3px;">Contributors' board for the last 5 days</h3>
<p style="margin-top: 2px; margin-bottom: 2px; ">Can it help your motivation? ;-) That said, remember this is a collective effort. Every fix counts. 
  But no shame if you don't have much time for it :-)</p>
<table style="">${leaderBoard}</table>


<div style="background-color: lightyellow; padding: 10px; width: auto;">
  <h3 style="margin-top: 5px; margin-bottom: 1px; padding-bottom: 3px;">How does it work?</h3>
  <ul style="padding-left: 20px;">
  <li>you're the only one to have been asked to fix it</li>
  <li>they should be fixable: they have at least one image</li>
  <li>your fix should have a big impact as we prioritize products by popularity (number of scans)</li>
  </ul>
</div>


<p>Kind regards</p>
</body>
</html>
EOF
)

echo "${emailToSend}"
echo "${emailToSend}" | sendmail -t

[[ ${mode} == "i" ]] && read -p "Press [Enter] key to go to next contributor..."
[[ ${mode} == "test" ]] && exit 0

done

exit 0
