#!/bin/bash
export PATH="/usr/local/bin:$PATH"
echo "Launching datasette..."
# -h 0.0.0.0 is the IP address, meaning here it is listening to all IP addresses
# --metadata metadata.yml \
# --setting facet_time_limit_ms 80000 \  : stop facet computation if query is greater than 80 seconds
# --setting suggest_facets off \         : don't suggest facets automatically (it's not working with a huge db)
# --setting truncate_cells_html 80 \     : cells with many contents are truncated to 80 chars
# --setting sql_time_limit_ms 80000 \    : stop if SQL qiery is greater than 80 seconds
# --setting max_csv_mb 6000 \            : must be high to allow people download whatever result in CSV
# --setting default_page_size 20 \       : results are 20 rows long
# --setting default_facet_size 10 \      : facets are 10 items long
# --load-extension /usr/lib/sqlite3/pcre.so  : load SQLite extension allowing REGEXP
datasette serve off-stats.db -i products.db \
    -h 0.0.0.0 \
    --metadata metadata.yml \
    --setting facet_time_limit_ms 80000 \
    --setting suggest_facets off \
    --setting truncate_cells_html 80 \
    --setting sql_time_limit_ms 80000 \
    --setting max_csv_mb 6000 \
    --setting default_page_size 20 \
    --setting default_facet_size 10 \
    --setting max_returned_rows 10000 \
    --load-extension /usr/lib/sqlite3/pcre.so