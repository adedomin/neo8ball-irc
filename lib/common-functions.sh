#!/usr/bin/env bash
# Copyright 2018 Anthony DeDominic <adedomin@gmail.com>
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

# $1     - message to uri encode
# stdout - uri encoded string
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
    printf -v now '%(%s)T' -1

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
        amt='diff'
    fi

    (( amt > 1 )) && unit+='s'

    echo "$amt $unit $past_suffix"
}
export -f reladate

# get default location for user
# $1      - user
# return  - 1 on failure
# stdout  - user's location
GET_LOC() {
    [[ -z "$PERSIST_LOC" ]] && PERSIST_LOC="$PLUGIN_TEMP"
    local weatherdb="$PERSIST_LOC/weather-defaults.db"
    awk -v user="$1" -- '
        index($0, user":") == 1 {
            print substr($0, length(user)+2)
            found = 1
            exit
        }
        END { if (!found) exit 1; else exit 0 }
    ' "$weatherdb"
}
export -f GET_LOC

# save location ($2) for user ($1)
# for weather plugins
# $1     - user
# $2     - location
# return - nonzero on failure
SAVE_LOC() {
    [[ -z "$PERSIST_LOC" ]] && PERSIST_LOC="$PLUGIN_TEMP"
    local weatherdb="$PERSIST_LOC/weather-defaults.db"
    [[ ! -f "$weatherdb" ]] && true > "$weatherdb"
    local weatherdb_tmp="$weatherdb.tmp"

    local lock="$PLUGIN_TEMP/weatherdb.save-lock"
    [[ ! -f "$lock" ]] && (
        umask 177
        true > "$lock"
    )
    exec 40<> "$lock"
    flock --exclusive --wait 2 40 || return

    if ! awk -F : \
        -v user="$1" \
        -v location="$2" -- \
        '$1 == user { next }
        { print }
        END { print user ":" location }' \
        "$weatherdb" \
    > "$weatherdb_tmp"; then
        rm -f -- "$weatherdb_tmp"
        exec 40<&-
        return 1
    fi

    if ! mv -- "$weatherdb_tmp" "$weatherdb"; then
        rm -f -- "$weatherdb_tmp"
        exec 40<&-
        return 1
    fi
    exec 40<&-
}
export -f SAVE_LOC

# Converts &amp;-like char entities to utf8 character equivalents
#
# <STDIN>:  stream to convert
# <STDOUT>: the stream with character entities replaced
HTML_CHAR_ENT_TO_UTF8() {
    sed -f "$LIB_PATH/html-to-utf8.sed"
}
export -f HTML_CHAR_ENT_TO_UTF8

# Checks if a channel is in a *_IGNORE style environment variable
# SEE: config.sh -> PAGETITLE_IGNORE
#
# $1     - channel name
# $2     - *_IGNORE variable, contains newline separated channel names
# return - returns code 0 if variable found, 1 otherwise
CHANNEL_IN_IGNORE_LIST() {
    [[ -z "$2" || -z "$1" ]] && return 1
    case "$2" in
        *$'\n'"$1"$'\n'*) return 0 ;;
        "$1"$'\n'*)       return 0 ;;
        *$'\n'"$1")       return 0 ;;
        "$1")             return 0 ;;
    esac
    return 1
}
export -f CHANNEL_IN_IGNORE_LIST
