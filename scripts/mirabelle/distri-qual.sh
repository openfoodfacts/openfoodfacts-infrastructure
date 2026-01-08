#!/bin/bash
export PATH="/usr/local/bin:$PATH"

# This script:
# 1. update the database related to data quality issues: dq-issues.db
#    - add new products having an issue, that weren't before
#    - update existing products:
#      - update the ones which are not existing anymore in the OFF database
#      - update the ones which have no issue anymore
# 5. send data quality daily email


# ---- TODO
# * Features for end users:
#   * link to help page: forum? wiki?
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

#TAGLINE="<p style='color: blue;'>Data quality daily is facing issues since a few days. We're working on it. Data quality stats and contributors' leaderboard bellow are wrong, sorry...</p>"
#TAGLINE='<p style="color: blue;">NEW FEATURE: 3 more products link (see below)</p>'
#TAGLINE='<p style="color: blue;">NEW STATS: see Daily stats section below</p>'
#TAGLINE='<p style="color: blue;">Event: every month we organise the Data quality monthly, a dedicated one hour meeting. <a href="https://forum.openfoodfacts.org/t/data-quality-monthly-meeting-2023-05-03/250">Next one will take place TODAY!</a>.</p>'
#TAGLINE="<p style='color: blue;'>During summertime, less people are helping so don't hesitate to do a little bit more if you can :)</p>"
#TAGLINE="<p style='color: blue;'>During a few days, we're focusing on products from the UK and France, to understand if we can reach threshold faster.</p>"
#TAGLINE="<p style='color: blue;'>DECEMBER CHALLENGE: we've done it!! Congrats everyone! (Will we go below 4.9% or even 4.8% ;-) ?)</p>"
#TAGLINE="<p style='color: blue;'>Happy new year! DECEMBER CHALLENGE: we did it! We have gone below 4.9%. Thanks everyone!</p>"
#TAGLINE="<p style='color: blue;'>Stats are not so good, don't forget to do your homework :) Thanks everyone!</p>"
#TAGLINE="We have removed more than 13,000 data quality errors on Friday 06/12. Stats should reflect this."

# ---- Requirements
# * sqlite (standard Debian package)
# * sendmail command (via postfix or another smtp client)
# * data come from mirabelle.openfoodfacts.org

printf "${0} launched $(date +'%Y-%m-%dT%H:%M:%S')\n\n"
env
echo "---------------------------"
cd /home/off/mirabelle || { echo "Can't cd. Exiting..."; exit 1; }
PATH=/sbin:/bin:/usr/sbin:/usr/bin
TODAY=$(date "+%Y-%m-%d")



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

usage=$(cat <<EOF
Usage: distri-qual.sh --{mode}

 mode: "test"      => send an email to the first user and stop; do not update the DB
       "i"         => interactive
       "noupdates" => do not update DB (updated and new products), but send emails and update sent emails in DB
EOF
)
mode="$1"

[[ $mode == "--normal" || $mode == "--test" || $mode == "--i" || $mode == "--noupdates" || $mode == "--replay" ]] && \
   echo "$mode mode" || \
   { echo "This script is dangerous and it needs options. You should know what you're doing..."; echo "$usage"; exit "5"; }

# Goal: percent of products with a data quality error; see: https://world.openfoodfacts.org/data-quality-errors
goalInPercent=0.9 # TODO: use it when more than 10 members

# Edit link
editLink="https://world.openfoodfacts.org/cgi/product.pl?type=edit&code="

function ifFailed {
    EXIT=$?
    if [[ $EXIT -ne 0 ]] ; then
       printf '%s\n' "$1" >&2 ## Send message to stderr.
       exit "${2-1}" ## Return a code specified by $2, or 1 by default.
    fi
}

function log {
    echo "$(date +'%Y-%m-%dT%H:%M:%S') - $1"
}

# 2. ---- read useful data; exit if the databases are not reachable or not up to date
log "Reading usefull data..."

lastProductEditedOn=$(sqlite3 products.db "select last_modified_datetime from [all] order by last_modified_datetime desc limit 1;")
# Exit after 18 retries if the database is not up to date
counter=1
while [[ "${lastProductEditedOn}" != "${TODAY}"* ]]; do
  # Exit after 60 tries (600 min = 10 hours)
  [[ "${counter}" -gt 60 ]] && { log "Retried ${counter} times, now exit..."; exit 1; }
  ((counter++))
  log "Last product edited on products.db: ${lastProductEditedOn}. DB is not up to date. Retrying in 10 minutes..."
  [[ ${mode} == "noupdates" ]] && break
  [[ ${mode} == "test" ]] && break
  sleep 10m
  lastProductEditedOn=$(sqlite3 products.db "select last_modified_datetime from [all] order by last_modified_datetime desc limit 1;")
done
log "Last product edited on: ${lastProductEditedOn}" # 2023-01-16T02:39:22Z


# total nb of products
totalNbOfProducts=$(sqlite3 products.db "select count(rowid) from [all];")
log "Total nb of products: ${totalNbOfProducts}"

# total nb of modified products
totalNBOfModifiedProducts=$(sqlite3 products.db "select count(rowid) from [all] where DATE(last_modified_datetime) = DATE('now', '-1 day');")
log "Total nb of products modified yesterday: ${totalNBOfModifiedProducts}"

# total nb of new products
totalNBOfNewProducts=$(sqlite3 products.db "select count(rowid) from [all] where DATE(created_datetime) = DATE('now', '-1 day');")
log "Total nb of products created yesterday: ${totalNBOfNewProducts}"

totalNBOfNewProductsLastSevenDays=$(sqlite3 -separator $' ' products.db "select
  (select count(rowid) from [all] where DATE(created_datetime) = DATE('now', '-7 day')),
  (select count(rowid) from [all] where DATE(created_datetime) = DATE('now', '-6 day')),
  (select count(rowid) from [all] where DATE(created_datetime) = DATE('now', '-5 day')),
  (select count(rowid) from [all] where DATE(created_datetime) = DATE('now', '-4 day')),
  (select count(rowid) from [all] where DATE(created_datetime) = DATE('now', '-3 day')),
  (select count(rowid) from [all] where DATE(created_datetime) = DATE('now', '-2 day')),
  (select count(rowid) from [all] where DATE(created_datetime) = DATE('now', '-1 day'));")
spSD=$(/usr/local/bin/spark "${totalNBOfNewProductsLastSevenDays}")
#log "${spSD}"

# nb of products with issues (minus non solvable?) and percentage
nbOfProductsWithAnIssue=$(sqlite3 products.db "select count(data_quality_errors_tags) from [all] where data_quality_errors_tags != '';")
ifFailed "products.db: database error $?" "2" # Exit if the database is not reachable

percentOfProductsWithAnIssue=$(echo "scale=3; (${nbOfProductsWithAnIssue} * 100) / ${totalNbOfProducts}" | bc)
log "Nb of products with issues: ${nbOfProductsWithAnIssue} representing ${percentOfProductsWithAnIssue} percents"

# nb of participants
nbOfContributors=$(sqlite3 dq-members.db "select count(id) from [members];")
log "Number of contributors: ${nbOfContributors}"
ifFailed "dq-members.db: database error $?" "2" # Exit if the database is not reachable

nbOfProductsFixedTwoDaysAgo=$(sqlite3 dq-issues.db "select count(*) from distrib where fixed_date == DATE('now','-1 day');")
log "Nb of products fixed two days ago: ${nbOfProductsFixedTwoDaysAgo}"
ifFailed "dq-issues.db: database error $?" "2" # Exit if the database is not reachable

lastProductEntriedOn=$(sqlite3 dq-issues.db "select entry_date from distrib order by entry_date desc limit 1;")
log "lastProductEntriedOn: ${lastProductEntriedOn}"

lastProductSentOn=$(sqlite3 dq-issues.db "select sent_date from distrib order by sent_date desc limit 1;")
log "lastProductSentOn: ${lastProductSentOn}"

printf "\n\n"



# 2b. ---- backup before updating
dbLastModifiedOn=$(date -r dq-issues.db +"%Y-%m-%d-%H-%M-%S")
log "Backup dq-issues.db to dq-issues.${dbLastModifiedOn}.db"
cp "dq-issues.db" "dq-issues.${dbLastModifiedOn}.db" # backup before update
ln -sf "dq-issues.${dbLastModifiedOn}.db" "dq-issues.previous.db"
find dq-issues.20* -mtime +5 -delete # delete backups older than 5 days
cp "dq-members.db" "dq-members.$(date -r dq-members.db +'%Y-%m-%d-%H-%M-%S').db"
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

# Test before update
log "Preview before adding products..."
sqlite3 < <( cat <<EOF
ATTACH DATABASE 'products.db' AS products;
ATTACH DATABASE 'dq-issues.db' AS [dq-issues];
select code, data_quality_errors_tags, last_modified_by from products.[all] as p where p.data_quality_errors_tags != "" and
  -- the products does not exist at all in distrib table
  NOT EXISTS (SELECT * FROM distrib where code = p.code)
  limit 7;
select count(*) || " errors never seen" || char(10) from products.[all] as p where p.data_quality_errors_tags != "" and NOT EXISTS (SELECT * FROM distrib where code = p.code);
select code, data_quality_errors_tags, last_modified_by from products.[all] as p where p.data_quality_errors_tags != "" and
  -- the product exists but its last entries has been fixed
  -- EXISTS
  --  (SELECT * FROM distrib where code = p.code and fixed_date != ""
  --     and code not in (select code from [all] group by code having count(code) > 1) -- avoid products' duplicates
  --   order by entry_date desc limit 1)
  p.code IN (-- products which last entry has been fixed (verified)
             SELECT a.code FROM [dq-issues].[distrib] as a
             where true
             and a.fixed_date != ""
             and a.code not in (select code from [all] group by code having count(code) > 1) -- avoid duplicates
             and a.entry_date in (-- last entry date of each product
                                  select max(entry_date) from [dq-issues].[distrib]
                                  where code = a.code)
            )
  limit 7;
EOF
)

log "Adding new products..."
[[ ${mode} == "i" ]] && read -p "Press [Enter] key to add new products and continue..."

# Update if we are not in "test" or "noupdates" mode
[[ ${mode} != "test" ]] && [[ ${mode} != "noupdates" ]] && sqlite3 < <( cat <<EOF
ATTACH DATABASE 'products.db' AS products;
ATTACH DATABASE 'dq-issues.db' AS [dq-issues];
insert into distrib (code, data_quality_errors, entry_date)
  select code, data_quality_errors_tags, DATE('now') from products.[all] as p
  where
    p.data_quality_errors_tags != "" and
    (
      -- either the products does not exist at all in distrib table
      NOT EXISTS (SELECT * FROM [dq-issues].[distrib] where code = p.code)
      or
      -- either the product exists but its last entries was fixed
      -- EXISTS
      --  (SELECT * FROM distrib where code = p.code and fixed_date != ""
      --     and code not in (select code from [all] group by code having count(code) > 1) -- avoid duplicates
      --   order by entry_date desc limit 1)
      p.code IN (-- products which last entry has been fixed (verified)
                 SELECT a.code FROM [dq-issues].[distrib] as a
                 where true
                 and a.fixed_date != ""
                 and a.code not in (select code from [all] group by code having count(code) > 1) -- avoid duplicates
                 and a.entry_date in (-- last entry date of each product
                                      select max(entry_date) from [dq-issues].[distrib]
                                      where code = a.code)
                )
    );
select changes() || " inserts of new errors" || char(10);
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
[[ ${mode} != "test" ]] && [[ ${mode} != "noupdates" ]] && sqlite3 dq-issues.db < <( cat <<EOF
ATTACH DATABASE 'products.db' AS products;
-- Mark products as fixed, from dq-issues that are not in products.db (products deleted from OFF database)
select * from distrib where fixed_date == "" and distrib.code not in (select code from products.[all]) limit 7;
update distrib
  set fixed_date = DATE('now')
    where fixed_date == ""
      and distrib.code not in (select code from products.[all]);
select changes() || " products deleted from OFF database" || char(10); -- returns nb of database rows that were changed by the most recently completed INSERT, DELETE, or UPDATE statement

-- Mark products as fixed, from dq-issues that do not have any quality issue in products.db
select * from distrib where fixed_date == "" and distrib.code in (select code from products.[all] as p where p.data_quality_errors_tags == "") limit 7;
update distrib
  set fixed_date = DATE('now')
    where fixed_date == ""
      and distrib.code in (select code from products.[all] as p where p.data_quality_errors_tags == "");
select changes() || " products that has been fixed" || char(10);
EOF
)




# 5.  Read metrics, build leader board and send data quality daily email

# |--|--|--|--|--|--:--|--|--|--|--|--:--|--|--|--|--|--:--|--|--|--|--|--|--|--|--|--|--|--:--|--|--|--|--|--:--|--|--|--|--|--:--|--|--|--|--|--|
# |                                                                       |
# |0h   2h: CSV export             ~11h Data quality daily                |0h   2h: CSV export             ~11h Data quality daily
# |Now -1                                                                 |Now


# Build metrics

# The products that have changed between 2AM yester and 2AM today.
nbOfNewProductsWithIssues=$(sqlite3 dq-issues.db "select count(*) from distrib where entry_date == DATE('now');")
log "nbOfNewProductsWithIssues: ${nbOfNewProductsWithIssues}"

nbOfNewProductsWithIssuesYesterday=$(sqlite3 dq-issues.db "select count(*) from distrib where entry_date == DATE('now', '-1 day');")
log "nbOfNewProductsWithIssuesYesterday: ${nbOfNewProductsWithIssuesYesterday}"

nbOfProductsFixedYesterday=$(sqlite3 dq-issues.db "select count(*) from distrib where fixed_date == DATE('now');")
#select * from distrib where fixed_date == DATE('now') order by fixed_date desc limit 7;
log "nbOfProductsFixedYesterday: ${nbOfProductsFixedYesterday}"; echo

averageNbOfProductsFixedPerDay=$(sqlite3 dq-issues.db "select (count(distinct(code))/14) from distrib where fixed_date >= DATE('now','-14 day');")
log "averageNbOfProductsFixedPerDay (14 days): ${averageNbOfProductsFixedPerDay}"

averageNbOfNewProductsInErrorPerDay=$(sqlite3 dq-issues.db "select (count(distinct(code))/14) from distrib where entry_date >= DATE('now','-14 day');")
log "averageNbOfNewProductsInErrorPerDay (14 days): ${averageNbOfNewProductsInErrorPerDay}"

averageNetProductsFixedPerDay=$((${averageNbOfProductsFixedPerDay}-${averageNbOfNewProductsInErrorPerDay}))
log "averageNetProductsFixedPerDay (14 days): ${averageNetProductsFixedPerDay}"

# TODO:
uniqScans=$(sqlite3 products.db "select sum(unique_scans_n) as scans from [all] where unique_scans_n is not null;")
log "uniqScans: ${uniqScans}"
uniqScansIssues=$(sqlite3 products.db "select sum(unique_scans_n) as scans from [all] where unique_scans_n is not null and [data_quality_errors_tags] != '';")
log "uniqScansIssues: ${uniqScansIssues}"
issuesInScansPercent=$( perl -e "printf( '%.3f', (${uniqScansIssues} / ${uniqScans}) * 100 )" )
log "(uniqScansIssues / uniqScans) * 100 = issuesInScansPercent: ${issuesInScansPercent}"
printf "\n\n"

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
log "leaderBoard: ${leaderBoard}"


# Compute number of days to reach the goalInPercent
# 6.0 - 5.5 = 0.5
# 2,600,000 * 0.005 = 13000 products
# 13000 / (moyenne quotidienne sur 30 jours 100) = 4.2 months
#        - (1.9% de progression du nombre total de produits par mois * 4) (mais ca ne joue pas beaucoup)
# or
# Compute average net product fixed per day: ~150
# and divide 13000/150 = 86 jours = 13 semaines




# 5.1 Iterate over members
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
ATTACH DATABASE 'dq-issues-non-fixable.db' as non_fixable;
ATTACH DATABASE 'products.db' AS products;
SELECT distrib.id, p.code, CAST(p.unique_scans_n as INTEGER) as pop, p.data_quality_errors_tags --, p.countries_en
 FROM products.[all] as p
  inner join distrib on p.code = distrib.code
  where
    (distrib.sent_date == "" or distrib.sent_date IS NULL or DATE(distrib.sent_date) < DATE('now', '-50 days'))
    and (distrib.fixed_date == "" or distrib.fixed_date IS NULL)
    and (p.image_nutrition_url != "")
    and (p.image_ingredients_url != "")
    and (p.owner not like "org-%")        -- orgs are (as nestle) are sometimes sending wrong data every day
    and (distrib.code NOT IN (SELECT code FROM non_fixable))
    and (p.data_quality_errors_tags not like "%nutrition-value-over-105-fruits-vegetables-nuts-estimate-from-ingredients%") -- too much false positives with this issue
    and (p.energy_100g > 160) -- avoid products with low energy, with frequent errors due to rounded values
    -- and (p.countries_en like "%kingdom%" or (p.countries_en like "%france%" and random() % 10 == 0))
    and (pop > 0 or random() % 5 == 0)
  order by random() -- pop DESC
  limit 3
;
EOF
)
log "--"

# 5.1.1 Build product list
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

echo; log "Sending email --------------------------------------------------------------------------------------"

# 5.1.2 Send email
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
${TAGLINE}

<h3 style="margin-bottom: 1px; padding-bottom: 3px;">Below are <strong>your</strong> 3 products to fix:</h3>
<ul style="padding-left: 20px;">
${products_list}
</ul>

<p><strong style="color: crimson;">Want to be a hero today?</strong> Check out 3 more products:<br/>
<a href="https://link.openfoodfacts.org/more-issues-please">
https://link.openfoodfacts.org/more-issues-please</a>
</p>

<p><strong>For hardcore fixers ;-)</strong> Check randomized data quality errors list:<br/>
<a href="https://link.openfoodfacts.org/data-quality-errors-random">
https://link.openfoodfacts.org/data-quality-errors-random</a>
</p>

<div style="background-color: lightgrey; padding: 10px; width: auto;">
<p>Hard to fix some products? 
   First, you can a have look to this <a href="https://wiki.openfoodfacts.org/Data_quality_issues_which_can%27t_be_fixed">wiki page</a>.
   Then, you can either write us <a href="mailto:contact@openfoodfacts.org">an email</a>,
   ask your question in the <a href="https://forum.openfoodfacts.org/c/be-a-part-of-it/database/25">database
   category of our forum</a>, or join the <a href="https://slack.openfoodfacts.org">#quality-data group on Slack</a>.</p>
</div>

<h3 style="margin-bottom: 1px; padding-bottom: 3px;">Daily stats</h3>
All data and stats in this email are made from the last CSV export, where last product was added on ${lastProductEditedOn}.
<ul style="padding-left: 20px;">
<li>Total nb of products: $(echo "${totalNbOfProducts}" | sed ':a;s/\B[0-9]\{3\}\>/,&/;ta')</li>
<li>Nb of products with issues: $(echo "${nbOfProductsWithAnIssue}"| sed ':a;s/\B[0-9]\{3\}\>/,&/;ta')
    representing ${percentOfProductsWithAnIssue} percents</li>
<li>Nb of products modified yesterday (including new products): ${totalNBOfModifiedProducts}</li>
<li>Nb of products created yesterday (new products): ${totalNBOfNewProducts}</li>
<li>Nb of products created last seven days: ${spSD}</li>
<li>Nb of products with new issues two days ago: ${nbOfNewProductsWithIssuesYesterday}</li>
<li>Nb of products fixed (yesterday): <strong>${nbOfProductsFixedYesterday}</strong></li>
<li>Nb of products with new issues (yesterday): ${nbOfNewProductsWithIssues}</li>
<li>FYI: <a href="https://mirabelle.openfoodfacts.org/_memory/errors_from">
    where do the errors come from?</a> (to help others optimize their contributions)
</li>
<li>Average nb of products fixed per day (14 days): ${averageNbOfProductsFixedPerDay}</li>
<li>Average nb of new products in error per day (14 days): ${averageNbOfNewProductsInErrorPerDay}</li>
<li>Average net products fixed per day (14 days): ${averageNetProductsFixedPerDay}</li>
<li>Check out our nice <a href="https://mirabelle.openfoodfacts.org/-/dashboards/data-quality-dashboard">dashboard</a></li>
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
<hr/>
<p>You can <a href="https://mirabelle.openfoodfacts.org/-/data-quality-daily/subscribe">unsubscribe</a> (or make a pause) at any time.</p>
</body>
</html>
EOF
)

log "${emailToSend}"
echo "${emailToSend}" | sendmail -t

[[ ${mode} == "i" ]] && read -p -r "Press [Enter] key to go to next contributor..."
[[ ${mode} == "test" ]] && exit 0
#[[ ${mode} == "noupdates" ]] && exit 0

done

exit 0
