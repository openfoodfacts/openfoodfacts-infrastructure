#!/bin/bash

# usage: ./empty2null.sh mydb.db

teefile=tmp.txt

function empty2null() {
  for t in $(
sqlite3 "$db" "SELECT name FROM sqlite_master
WHERE type=='table' ORDER BY name" | tee ${teefile} )
  do
    nc=0
    onec=''
    mulc=''
    where='WHERE'
    cma="UPDATE OR ABORT \"${t}\" SET
 "
    for c in $( 
printf "SELECT '\"'||name||'\"' FROM pragma_table_info('%s')
WHERE type == 'INTEGER' or type == 'FLOAT' ORDER BY cid ASC;\\n" "$t" \
      | sqlite3 "$db" | tee -a ${teefile} )
    do
      onec+=$(printf "%s %s = NULL" "$cma" "$c")
      mulc+=$(printf "%s %s = IIF(%s=='',NULL,%s)" "$cma" "$c" "$c" "$c")
      cma='
,'
      test $nc -gt 0 && where+=' OR'
      where+=" $c==''"
      nc=$(( nc + 1 ))
    done
    if [ $nc -gt 0 ]
    then
      if [ $nc -gt 1 ]
      then
        printf '%s\n  %s;\n' "$mulc" "${where}"
      else
        printf '%s\n  %s;\n' "$onec" "${where}"
      fi
    fi
  done
}

db=$1

echo "$(date +'%Y-%m-%dT%H:%M:%S') - Building query"
sql=$(empty2null)
echo "$sql"

echo "$(date +'%Y-%m-%dT%H:%M:%S') - Converting..."
sqlite3 "$db" "$sql"
echo "$(date +'%Y-%m-%dT%H:%M:%S') - ... converting empty to NULL ended"
