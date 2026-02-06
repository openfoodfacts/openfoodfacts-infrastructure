#!/bin/bash
export PATH="/usr/local/bin:$PATH"
echo "Launching datasette..."
# -h 0.0.0.0 is the IP address, meaning here it is listening to all IP addresses
# --metadata metadata.yml \
# --setting facet_time_limit_ms 80000 \  : stop facet computation if query is greater than 80 seconds
# --setting suggest_facets off \         : don't suggest facets automatically (it's not working with a huge db)
# --setting truncate_cells_html 80 \     : cells with many contents are truncated to 80 chars
# --setting sql_time_limit_ms 240000 \   : stop if SQL query is greater than 240 seconds
# --setting max_csv_mb 6000 \            : must be high to allow people download whatever result in CSV
# --setting default_page_size 20 \       : results are 20 rows long
# --setting default_facet_size 10 \      : facets are 10 items long
# --setting max_returned_rows 30000 \    : 30000 maximum rows are returned on a given query
# --cross-db \                           : allows to make request across all the opened DB, via the _memory DB
# --load-extension /home/off/mirabelle/regex0.so \ : load SQLite sqlite-regex regexp engine (does not work); see https://github.com/asg017/sqlite-regex
# --load-extension /home/off/mirabelle/regexp.so \ : load SQLite sqlite-regex regexp engine; see https://github.com/nalgeon/sqlean
# --load-extension /usr/lib/sqlite3/pcre.so  : load SQLite extension allowing REGEXP
datasette serve -i products.db -i products_2023_01.db -i products_2021_09.db -i previous.db -i usda.db -i rappelconso_v2_gtin_trie.db \
    off-stats.db dq-issues.db dq-issues-non-fixable.db dq-issues.previous.db adjusted_nutrition_merged_output.db \
    -h 0.0.0.0 \
    --metadata metadata.yml \
    --setting facet_time_limit_ms 80000 \
    --setting suggest_facets off \
    --setting truncate_cells_html 70 \
    --setting sql_time_limit_ms 280000 \
    --setting max_csv_mb 8000 \
    --setting default_page_size 20 \
    --setting default_facet_size 10 \
    --setting max_returned_rows 5000000 \
    --crossdb \
    --load-extension /usr/lib/sqlite3/pcre.so \
    --static assets:static-files/ \
    --load-extension /home/off/mirabelle/regexp.so
    #--load-extension /home/off/mirabelle/regex0.so
    #--plugins-dir=plugins
