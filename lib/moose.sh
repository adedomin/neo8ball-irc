#!/usr/bin/env bash
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

MOOSE_URL='http://ghetty.space:7512'

if [ -n "$MOOSE_IGNORE" ]; then
    for channel in $MOOSE_IGNORE; do
        if [ "$channel" = "$1" ]; then
            echo ":mn $3 moose command disabled on $1"
            exit 0
        fi
    done
fi

if [[ "$4" =~ ^search ]]; then
    # shellcheck disable=2034
    read -r srch q <<< "$4"
    if [ -z "$q" ]; then
        echo ":m $1 search command requires a query"
        exit 0
    fi
    echo ":m $1 Moose Found: $(
        curl "$MOOSE_URL/gallery/newest?q=$(URI_ENCODE "$q")" \
            2>/dev/null \
        | jq '.[] | .name' | tr '\n' ' ' )"
    exit
fi

MOOSE_LOCK="$PLUGIN_TEMP/moose-lock"

if ! mkdir "$MOOSE_LOCK"; then
    echo ":mn $3 Please wait for the current moose to finish."
    exit 0
fi

# $1 - size of border
top_border() {
    echo -n '+'
    for (( i=0; i<${1}; i++ )); do
        echo -n '-'
    done
    echo '+'
}

KCOL=$'\003'
COLOR=(
['t']=''
['0']=$'\003'"00,00"
['1']=$'\003'"01,01"
['2']=$'\003'"02,02"
['3']=$'\003'"03,03"
['4']=$'\003'"04,04"
['5']=$'\003'"05,05"
['6']=$'\003'"06,06"
['7']=$'\003'"07,07"
['8']=$'\003'"08,08"
['9']=$'\003'"09,09"
['a']=$'\003'"10,10"
['b']=$'\003'"11,11"
['c']=$'\003'"12,12"
['d']=$'\003'"13,13"
['e']=$'\003'"14,14"
['f']=$'\003'"15,15"
)

# get moose and moose meta data
MOOSE="$(
    curl "$MOOSE_URL/moose/$(URI_ENCODE "${4:-random}")" 2>/dev/null
)"
MOOSE_ERR="$(jq -r '.status' <<< "$MOOSE")"
# check for error
if [ "$MOOSE_ERR" = 'error' ]; then
    echo ":m $1 404 - no such moose"
    rmdir "$MOOSE_LOCK" 2>/dev/null
    exit 0
fi
# extract name
MOOSE_NAME="$(jq -r '.name' <<< "$MOOSE")"
MOOSE_IMAGE=()
while read -r line; do
    MOOSE_IMAGE+=("$line")
done < <( 
    jq -r '.image' <<< "$MOOSE"
)

# trim moose image
#check from top down
for (( i=0; i<${#MOOSE_IMAGE[@]}; i++ )); do
    line="${MOOSE_IMAGE[$i]}"
    line="${line//t}"
    line="${line// }"
    if [ -z "$line" ]; then
        unset MOOSE_IMAGE["$i"]
    else
        break
    fi
done

# have to rebuild array due to how unsetting deletes positions
MOOSE_IMAGE=("${MOOSE_IMAGE[@]}")

# trim moose image
#check from down up
for (( i=${#MOOSE_IMAGE[@]}; i>=0; i-- )); do
    line="${MOOSE_IMAGE[$i]}"
    line="${line//t}"
    line="${line// }"
    if [ -z "$line" ]; then
        unset MOOSE_IMAGE["$i"]
    else
        break
    fi
done

# have to rebuild array due to how unsetting deletes positions
MOOSE_IMAGE=("${MOOSE_IMAGE[@]}")

# trim from left to right
for (( i=0; i<${#MOOSE_IMAGE}; i++ )); do
    for (( j=0; j<${#MOOSE_IMAGE[@]}; j++ )); do
        line="${MOOSE_IMAGE[$j]}"
        if [ "${line:0:1}" != 't' ]; then 
            noleft=1
            break
        fi
    done
    [ -n "$noleft" ] && break
    for (( j=0; j<${#MOOSE_IMAGE[@]}; j++ )); do
        line="${MOOSE_IMAGE[$j]}"
        MOOSE_IMAGE[$j]="${line:1}"
    done
done
unset noleft

# trim from right to left
for (( i=0; i<${#MOOSE_IMAGE}; i++ )); do
    for (( j=0; j<${#MOOSE_IMAGE[@]}; j++ )); do
        line="${MOOSE_IMAGE[$j]}"
        if [ "${line: -1}" != 't' ]; then 
            noleft=1
            break
        fi
    done
    [ -n "$noleft" ] && break
    for (( j=0; j<${#MOOSE_IMAGE[@]}; j++ )); do
        line="${MOOSE_IMAGE[$j]}"
        MOOSE_IMAGE[$j]="${line:0:-1}"
    done
done

for line in "${MOOSE_IMAGE[@]}"; do
    out=''
    for (( i=0; i<${#line}; i++ )); do
        if [ "${line:$i:1}" = 't' ]; then
            out+=' '
        else
            out+="${COLOR[${line:$i:1}]}@${KCOL}"
        fi
    done
    echo ":m $1 |$out"
    sleep "0.3s"
done 
if [ "$4" = 'latest' ] || [ "${4:-random}" = 'random' ]; then
    echo ":m $1 Moose Name: $MOOSE_NAME"
fi

rmdir "$MOOSE_LOCK" 2>/dev/null
