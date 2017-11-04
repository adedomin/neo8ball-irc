# Copyright 2017 prussian <genunrest@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


# common function used in plugins

# $1 - message to uri encode
URI_ENCODE() {
    echo -nE "$1" \
    | curl -Gso /dev/null \
        -w '%{url_effective}' \
        --data-urlencode @- '' \
    | cut -c 3-
}
export -f URI_ENCODE

# $1 - date in time
# turn a date into relative from now
# timestamp, e.g. 1 minute ago, ect.
reladate() {
    local unit past_suffix
    local -i thn now diff amt
    thn=$(TZ=UTC date --date "$1" +%s)
    now=$(date +%s)

    diff=$(( now - thn ))
    if (( diff > 0 )); then 
        past_suffix="ago"
    else
        past_suffix="from now"
        diff=$(( -diff ))
    fi

    if (( diff >= 31536000 )); then
        unit='year'
        amt='diff / 31536000'
    elif (( diff >= 604800 )); then
        unit='week'
        amt='diff / 604800'
    elif (( diff >= 86400 )); then
        unit='day'
        amt='diff / 86400'
    elif (( diff >= 3600 )); then
        unit='hour'
        amt='diff / 3600'
    elif (( diff >= 60 )); then
        unit='minute'
        amt='diff / 60'
    else
        unit='second'
        amt=diff
    fi
    
    (( amt > 1 )) && unit+='s'

    echo "$amt $unit $past_suffix"
}
export -f reladate

# get default location for user
# $1     - user
# return - location
GET_LOC() {
    [ -z "$PERSIST_LOC" ] && PERSIST_LOC="$PLUGIN_TEMP"
    local weatherdb="$PERSIST_LOC/weather-defaults.db"
    IFS=':' read -r USR arg < <( 
        grep "^$1:" "$weatherdb" 
    )
    echo "$arg"
}
export -f GET_LOC

# save location ($2) for user ($1) 
# for weather plugins
# $1: user
# $2: location
SAVE_LOC() {
    [ -z "$PERSIST_LOC" ] && PERSIST_LOC="$PLUGIN_TEMP"
    local weatherdb="$PERSIST_LOC/weather-defaults.db"
    local weatherdb_tmp="$weatherdb.$$.tmp"
    if [ ! -f "$weatherdb" ]; then
        touch "$weatherdb"
    fi

    if ! mkdir "$weatherdb.lock"; then
        (( ${3:-0} > 1 )) && return 1
        sleep 1s
        "$0" "$@"
        return
    fi
    
    if ! awk -F : \
        -v user="$1" \
        -v location="$2" -- \
        '$1 == user { next } 
        { print }
        END { print user ":" location }' \
        "$weatherdb" \
    > "$weatherdb_tmp"; then
        rmdir "$weatherdb.lock"
        return 1
    fi

    rmdir "$weatherdb.lock"
    mv "$weatherdb_tmp" "$weatherdb" \
        || return 1
}
export -f SAVE_LOC
