#!/bin/bash


cd /home/off/mirabelle

# ---- Setup
<<comments
Target DB (currently we only use id and code fields).

sqlite3 dq-issues.db < <( cat <<EOF
CREATE TABLE IF NOT EXISTS false_positives (
       id INTEGER PRIMARY KEY,
       code TEXT NOT NULL /*,
       property TEXT,
       value TEXT */
);
EOF


id|code          |property            |value
1 |0023673947553 |producer_data_issue |Fat typo, 13 is not possible
2 |1575583805368 |producer_data_issue |Fat can't be 0 g

comments

function log {
    echo "$(date +'%Y-%m-%dT%H:%M:%S') - $1"
}

log "Getting non fixable..."

# TODO: get other types of non-fixable products:
# * barcode_conflict:yes
# * barcode_clash:
# * ingredient_list:multiple:yes ?
# * nutrition_facts:multiple:yes ?
# * data_quality:product_opener_issue ?
# * wrong_barcode:yes ?
# * data_quality
#
issues=$(curl --silent https://api.folksonomy.openfoodfacts.org/products?k=producer_data_issue)
response=$?
# Exit if an error occured
[[ ${response} -ne 0 ]] && { log "Curl error: ${response}"; exit 1; }
issues=$(echo ${issues} | jq '.[].product')
#jq --raw-output '.[] | [.product, .v] | @csv'
# Exit if the API has returned nothing
[[ "${issues}" = "" ]] && { log "Found no issues. Process error? Keeping previous DB and exit..."; exit 1; }

# Delete previous file and create the new one
log "Delete previous DB and create the new one..."
rm dq-issues-non-fixable.db.bak
cp dq-issues-non-fixable.db dq-issues-non-fixable.db.bak || { log "Error: $?"; exit 1; }
rm dq-issues-non-fixable.db
touch dq-issues-non-fixable.db || { log "Error: $?"; exit 1; }

# Update false positive
sqlite3 dq-issues-non-fixable.db < <( cat <<EOF
CREATE TABLE IF NOT EXISTS non_fixable (id INTEGER PRIMARY KEY, code TEXT NOT NULL);
-- Insert
INSERT OR IGNORE INTO non_fixable (code) VALUES $(echo "${issues}" | sed 's/.*/(&)/;:l;N;s/\n\(.*\)$/, (\1)/;tl');
SELECT * FROM non_fixable;
EOF
)
[[ $? -ne "0" ]] && { log "Error: $?. Recovering backup."; mv -f dq-issues-non-fixable.db.bak dq-issues-non-fixable.db; exit 1; }

log "End of script. Normal exit with error code 0"
exit 0

