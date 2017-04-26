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

declare -A COLOR
KCOL=$'\003'
COLOR=(
['white']=$'\003'"00,00"
['black']=$'\003'"01,01"
['navy']=$'\003'"02,02"
['green']=$'\003'"03,03"
['red']=$'\003'"04,04"
['brown']=$'\003'"05,05"
['purple']=$'\003'"06,06"
['olive']=$'\003'"07,07"
['yellow']=$'\003'"08,08"
['lime']=$'\003'"09,09"
['teal']=$'\003'"10,10"
['cyan']=$'\003'"11,11"
['blue']=$'\003'"12,12"
['fuchsia']=$'\003'"13,13"
['grey']=$'\003'"14,14"
['lightgrey']=$'\003'"15,15"
)

# get moose and moose meta data
MOOSE="$(curl "http://captmoose.club/moose/$(URI_ENCODE "$4")" 2>/dev/null)"
# check for error status
MOOSE_ERR="$(jq -r '.error' <<< "$MOOSE")"
if [ "$MOOSE_ERR" = 'not found' ]; then
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
    jq -r '.moose[] | join(" ")' <<< "$MOOSE" 
)

# trim moose image
#check from top down
for (( i=0; i<${#MOOSE_IMAGE[@]}; i++ )); do
    line="${MOOSE_IMAGE[$i]}"
    line="${line//transparent}"
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
    line="${line//transparent}"
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
        read -r first other <<< "${MOOSE_IMAGE[$j]}"
        if [ "$first" != 'transparent' ]; then 
            noleft=1
            break
        fi
    done
    [ -n "$noleft" ] && break
    for (( j=0; j<${#MOOSE_IMAGE[@]}; j++ )); do
        read -r first other <<< "${MOOSE_IMAGE[$j]}"
        MOOSE_IMAGE[$j]="$other"
    done
done
unset noleft

# trim from right to left
for (( i=0; i<${#MOOSE_IMAGE}; i++ )); do
    for (( j=0; j<${#MOOSE_IMAGE[@]}; j++ )); do
        read -r -a elements <<< "${MOOSE_IMAGE[$j]}"
        if [ "${elements[-1]}" != 'transparent' ]; then 
            noleft=1
            break
        fi
    done
    [ -n "$noleft" ] && break
    for (( j=0; j<${#MOOSE_IMAGE[@]}; j++ )); do
        read -r -a elements <<< "${MOOSE_IMAGE[$j]}"
        unset elements[-1]
        MOOSE_IMAGE[$j]="${elements[@]}"
    done
done

sizeof=(${MOOSE_IMAGE[0]})
echo ":m $1 $(top_border "${#sizeof[@]}")"
for line in "${MOOSE_IMAGE[@]}"; do
    out=''
    line=($line)
    for (( i=0; i<${#line[@]}; i++ )); do
        if [ "${line[$i]}" = 'transparent' ]; then
            out+=' '
        else
            out+="${COLOR[${line[$i]}]}@${KCOL}"
        fi
    done
    echo ":r PRIVMSG $1 :|$out|"
    sleep "0.3s"
done 
echo ":m $1 $(top_border "${#sizeof[@]}")"
echo ":m $1 Name -> $MOOSE_NAME"

rmdir "$MOOSE_LOCK" 2>/dev/null
