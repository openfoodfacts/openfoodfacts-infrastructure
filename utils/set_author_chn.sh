# use it with source !
# eg; source /opt/openfoodfacts-infrastructure/utils/set_author_chn.sh

# set git author name to avoid typing it
declare -x GIT_AUTHOR_NAME="Charles Nepote"
# rot13 email hiding (encrypt with tr 'A-Za-z' 'N-ZA-Mn-za-m')
declare -x GIT_AUTHOR_EMAIL=$(echo puneyrf@arcbgr.bet| tr 'N-ZA-Mn-za-m' 'A-Za-z')
declare -x EDITOR=nano
