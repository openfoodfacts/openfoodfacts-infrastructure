# use it with source !

# set git author name to avoid typing it
declare -x GIT_AUTHOR_NAME="Alex Garel"
# rot13 email hiding (encrypt with tr 'A-Za-z' 'N-ZA-Mn-za-m')
declare -x GIT_AUTHOR_EMAIL=$(echo nyrk@bcrasbbqsnpgf.bet| tr 'N-ZA-Mn-za-m' 'A-Za-z')
