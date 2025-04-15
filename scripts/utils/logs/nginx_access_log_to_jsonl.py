#!/usr/bin/env python3
"""A script to export nginx acces logs to json.

By default it will blur ip addresses using sha1.
"""
r"""

Example use:
```bash
# getting logs, and 8 file (days) back
time python3 /home/alex/nginx_access_log_to_jsonl.py proxy-off-access.log{,.1,.{2..8}.gz} |gzip > /home/alex/nginx_logs.jsonl.gz
```

Import in duckdb:
```sql
/* base import json */
CREATE TABLE logs AS SELECT * FROM read_json(
  'nginx_logs.jsonl.gz',
  columns={
    status: 'INT',
    body_bytes_sent: 'INT',
    time_local: 'TIMESTAMP',
    remote_addr: 'VARCHAR',
    remote_user: 'VARCHAR',
    request: 'VARCHAR',
    http_referer: 'VARCHAR',
    http_user_agent: 'VARCHAR',
    request_time: FLOAT
  },
  ignore_errors=true);
/* add req info */
ALTER TABLE logs add column req STRUCT(verb VARCHAR, uri VARCHAR, params VARCHAR, protocol VARCHAR);
/* note that if we don't put the non capturing on the group needed for params, regexp_extract messes protocol with this other capture… */
update logs set req = regexp_extract(request, '^ *(?P<verb>\w+) (?P<uri>[^? ]+)(?:\?(?P<params>[^ ]*))? (?P<protocol>.*)$', ['verb', 'uri', 'params', 'protocol']);
/* compute req_style and req_type */
ALTER TABLE logs add column req_style VARCHAR;
ALTER TABLE logs add column req_type VARCHAR;
update logs set req_style = case
    when req.uri ~ '/api/.*' then 'api'
    when req.uri ~ '/cgi/.*' then 'cgi'
    else 'web'
  end
;
update logs set req_type = regexp_extract(req.uri, '/api/v.?/([^/]+)(?:/.*)?' ,1)
where req_style = 'api';
update logs set req_type = case
    when req.uri ~ '/data.*' then 'data'
    when req.uri ~ '/(mountaj|m\xc9\x99hsul|\xd0\xbf\xd1\x80\xd0\xbe\xd0\xb4\xd1\x83\xd0\xba\xd1\x82|gynnyrch|produkt|product|product|product|produkto|producto|toode|produkto|produit|produto|term\xc3\xa9k|produk|\xe8\xa3\xbd\xe5\x93\x81|afaris|\xd3\xa9\xd0\xbd\xd1\x96\xd0\xbc|\xec\x83\x9d\xec\x84\xb1\xeb\xac\xbc|berhem|\xe0\xa4\x89\xe0\xa4\xa4\xe0\xa5\x8d\xe0\xa4\xaa\xe0\xa4\xbe\xe0\xa4\xa6\xe0\xa4\xa8|produk|produkt|\xe0\xa4\x89\xe0\xa4\xa4\xe0\xa5\x8d\xe0\xa4\xaa\xe0\xa4\xbe\xe0\xa4\xa6\xe0\xa4\xa8|product|product|product|produkt|produkt|produit|produto|produto|produto|\xd0\xbf\xd1\x80\xd0\xbe\xd0\xb4\xd1\x83\xd0\xba\xd1\x82|product|proizvod|produkto|\xc3\xbcr\xc3\xbcn|\xd0\xbf\xd1\x80\xd0\xbe\xd0\xb4\xd1\x83\xd0\xba\xd1\x82|\xe4\xba\xa7\xe5\x93\x81|\xe7\x94\xa2\xe5\x93\x81|\xe7\x94\xa2\xe5\x93\x81).*' then 'product'
    when req.uri ~ '^/(countries|nutrition-grades|nova-groups|environmental-score|brands|categories|labels|packaging|origins|manufacturing-places|packager-codes|ingredients|additives|vitamins|minerals|amino-acids|nucleotides|other-nutritional-substances|allergens|traces|misc|languages|contributors|states|data-sources|entry-dates|last-edit-dates|last-check-dates|teams)/?$' then 'facets_count'
    /* here we don't know if it's text content or a facets search in another language */
    when req.uri ~ '^/[^/]+$' then 'content|facets'
    when req.uri ~ '^/([^/]+/[^/]+)+$' then 'facets_search'
    when req.uri ~ '^/([^/]+/[^/]+)+/[^/]+$' then 'facets_count'
    else 'unknown'
  end
where req_style = 'web';
update logs set req_type = regexp_extract(req.uri, '/cgi/([^.]+)\.pl.*' ,1)
where req_style = 'cgi';
```
"""

import argparse
import gzip
import hmac
import json
import locale
import random
import re
import sys
from datetime import datetime


locale.setlocale(locale.LC_ALL, 'en_US.UTF-8')

# we will use hmac to encode IPs, we will thus have consistent hashing of the same IP
# for the session
SECRET = ("".join(chr(i) for i in random.sample(list(range(32,126)) * 64, 64))).encode('ascii')


def nginx_time(time_str):
    """Parse a nginx time field and convert to a iso format

    eg: 21/Jan/2025:11:00:58 +0000
    """
    return datetime.strptime(time_str, "%d/%b/%Y:%H:%M:%S %z").isoformat()


COMBINED_REGEXP = re.compile(
    r"""
        ^(?P<remote_addr>[^-]*)\ ?-
        \ (?P<remote_user>[^[]*)\ *
        \ \[(?P<time_local>[^]]*)\]
        \ "(?P<request>[^"]*)"
        \ (?P<status>\d+)
        \ (?P<body_bytes_sent>\d+)
        \ "(?P<http_referer>[^"]*)"
        \ "(?P<http_user_agent>[^"]*)"
    """,
    re.VERBOSE,
)

COMBINED_FIELDS = [
    "remote_addr",
    "remote_user",
    "time_local",
    "request",
    "status",
    "body_bytes_sent",
    "http_referer",
    "http_user_agent",
]
COMBINED_TRANSFORM = {
    # time to iso time
    "time_local": lambda d: nginx_time(d['time_local']) if 'time_local' in d else None,
    # hash remote addr
    "remote_addr": lambda d: hmac.new(SECRET, d['remote_addr'].encode("utf-8"), 'sha1').hexdigest(),
}

OFF_REGEXP = re.compile(
    COMBINED_REGEXP.pattern + r"""
    \ ?(?P<request_time>\d+)?
    """,
    re.VERBOSE,
)
OFF_FIELDS = COMBINED_FIELDS + ["request_time"]
OFF_TRANSFORM = COMBINED_TRANSFORM

FORMATS={
    "combined": {
        "pattern": COMBINED_REGEXP,
        "fields": COMBINED_FIELDS,
        "transform": COMBINED_TRANSFORM
    },
    "off": {
        "pattern": OFF_REGEXP,
        "fields": OFF_FIELDS,
        "transform": OFF_TRANSFORM
    }
}


def iter_log(log_path):
    if log_path == "-":
        for log_line in sys.stdin:
            yield log_line
    elif log_path.endswith(".gz"):
        with gzip.open(log_path, 'rt') as log:
            for log_line in log:
                yield log_line
    else:
        with open(log_path) as log:
            for log_line in log:
                yield log_line


def nginx_data_iter(log_path, pattern=COMBINED_REGEXP, fields=COMBINED_FIELDS, transform=COMBINED_TRANSFORM):
    """
    Transform nginx access logs to jsonl

    Note that it makes some assumptions on the log, to follow the combined format

    combined '$remote_addr - $remote_user [$time_local] '
                '"$request" $status $body_bytes_sent '
                '"$http_referer" "$http_user_agent"';
    """
    for i, log_line in enumerate(iter_log(log_path)):
        try:
            matched = pattern.search(log_line)
            if matched is None:
                print(
                    "Error: Unexpected format in %s at line %s: %s" % (log_path, i, log_line),
                    file=sys.stderr
                )
                continue
            data = {field: matched.group(field) for field in fields}
            for field, fn in transform.items():
                data[field] = fn(data)
            yield data
        except Exception as e:
            print(
                "Error: Unexpected error in %s at line %s: %s - %s" % (log_path, i, e, log_line),
                file=sys.stderr
            )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description='Transform nginx acces logs to jsonl'
    )
    parser.add_argument("log_path", nargs="*", help="path to acces log files, or '-' for stdin")
    parser.add_argument(
        "--format",
        default="combined",
        help="the type of log to analyze: " + ", ".join(FORMATS.keys()))
    args = parser.parse_args()
    if args.format not in FORMATS:
        print("Unknown format %s" % args.format, file=sys.stderr)
        exit(1)
    for log_path in args.log_path:
        print("Starting %s" % log_path, file=sys.stderr)
        for data in nginx_data_iter(log_path, **FORMATS[args.format]):
            print(json.dumps(data))
        print("Processed %s" % log_path, file=sys.stderr)
