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

MOOSE_URL='https://moose.ghetty.space'

if [ -n "$MOOSE_IGNORE" ]; then
    for channel in $MOOSE_IGNORE; do
        if [ "$channel" = "$1" ]; then
            echo ":mn $3 moose command disabled on $1"
            exit 0
        fi
    done
fi

q="$4"

# parse args
# shellcheck disable=SC2034
while IFS='=' read -r key val; do
    case "$key" in
        -l|--latest)
            q='latest'
        ;;
        -r|--random)
            q='random'
        ;;
        -s|--search)
            SEARCH=1
        ;;
        -h|--help)
            echo ":m $1 usage: $5 [--latest|--random|--search] [query]"
            echo ":m $1 Make Moose @ $MOOSE_URL"
            exit 0
        ;;
    esac
done <<< "$6"

if [ -n "$SEARCH" ]; then
    # shellcheck disable=2034
    if [ -z "$q" ]; then
        echo ":m $1 search command requires a query"
        exit 0
    fi
    MOOSE_SEARCH="$(
        curl "$MOOSE_URL/gallery/newest?q=$(URI_ENCODE "$q")" \
            2>/dev/null
    )"
    if [ "$MOOSE_SEARCH" = '[]' ]; then
        echo ":m $1 no moose found"
        exit 0
    fi
    echo ":m $1 Moose Found: $(
        jq '.[] | .name' <<< "$MOOSE_SEARCH" | tr '\n' ' '
    )"
    exit
fi

MOOSE_LOCK="$PLUGIN_TEMP/moose-lock"

if ! mkdir "$MOOSE_LOCK"; then
    echo ":mn $3 Please wait for the current moose to finish."
    exit 0
fi

KCOL=$'\003'
declare -A COLOR
COLOR=(
['t']=''
['0']=$'\003'"00"
['1']=$'\003'"01"
['2']=$'\003'"02"
['3']=$'\003'"03"
['4']=$'\003'"04"
['5']=$'\003'"05"
['6']=$'\003'"06"
['7']=$'\003'"07"
['8']=$'\003'"08"
['9']=$'\003'"09"
['a']=$'\003'"10"
['b']=$'\003'"11"
['c']=$'\003'"12"
['d']=$'\003'"13"
['e']=$'\003'"14"
['f']=$'\003'"15"
)

declare -A SHADERS
SHADERS=(
['1']='░'
['2']='▒'
['3']='▓'
['4']='█'
['5']=',01▓'
['6']=',01▒'
['7']=',01░'
)

# get moose and moose meta data
MOOSE="$(
    curl "$MOOSE_URL/moose/$(URI_ENCODE "${q:-random}")" 2>/dev/null
)"
MOOSE_ERR="$(jq -r '.status' <<< "$MOOSE")"
# check for error
if [ "$MOOSE_ERR" = 'error' ] || [ -z "$MOOSE" ]; then
    echo ":m $1 404 - Make it @ $MOOSE_URL/#?edit=$(URI_ENCODE "$4")"
    rmdir "$MOOSE_LOCK" 2>/dev/null
    exit 0
fi
# extract name
MOOSE_NAME="$(jq -r '.name' <<< "$MOOSE")"
MOOSE_DATE="$(jq -r '.created' <<< "$MOOSE")"
MOOSE_SHADED="$(jq -r '.shaded' <<< "$MOOSE")"
MOOSE_IMAGE=()
while read -r line; do
    MOOSE_IMAGE+=("$line")
done < <( 
    jq -r '.image' <<< "$MOOSE"
)

MOOSE_SHADING=()
if [ "$MOOSE_SHADED" = 'true' ]; then
    while read -r line; do
        MOOSE_SHADING+=("$line")
    done < <( 
        jq -r '.shade' <<< "$MOOSE"
    )
fi

# trim moose image
#check from top down
for (( i=0; i<${#MOOSE_IMAGE[@]}; i++ )); do
    line="${MOOSE_IMAGE[$i]}"
    line="${line//t}"
    line="${line// }"
    if [ -z "$line" ]; then
        unset MOOSE_IMAGE["$i"]
        [ "$MOOSE_SHADED" = 'true' ] &&
            unset MOOSE_SHADING["$i"]
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
        [ "$MOOSE_SHADED" = 'true' ] &&
            unset MOOSE_SHADING["$i"]
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
        if [ "$MOOSE_SHADED" = 'true' ]; then
            sline="${MOOSE_SHADING[$j]}"
            MOOSE_SHADING[$j]="${sline:1}"
        fi
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
        if [ "$MOOSE_SHADED" = 'true' ]; then
            sline="${MOOSE_SHADING[$j]}"
            MOOSE_SHADING[$j]="${sline:0:-1}"
        fi
    done
done

[ "$MOOSE_SHADED" = 'true' ] && declare -i shade_lineno
[ "$MOOSE_SHADED" != 'true' ] && symbol="${SHADERS['4']}"
for line in "${MOOSE_IMAGE[@]}"; do
    out=''
    [ "$MOOSE_SHADED" = 'true' ] && 
        shade_line="${MOOSE_SHADING["$shade_lineno"]}"
    for (( i=0; i<${#line}; i++ )); do
        if [ "${line:$i:1}" = 't' ]; then
            out+=' '
        else
            [ "$MOOSE_SHADED" = 'true' ] &&
                symbol="${SHADERS["${shade_line:$i:1}"]}"
            out+="${COLOR["${line:$i:1}"]}${symbol}${KCOL}"
        fi
    done
    echo -e ":m $1 \u200B$out"
    shade_lineno+=1
    sleep "0.3s"
done 
outstring=""
if [ "$q" = 'latest' ] || [ "${q:-random}" = 'random' ]; then
    outstring+=$'\002'"$MOOSE_NAME"$'\002'" -"
fi
echo ":m $1 $outstring Created $(reladate "$MOOSE_DATE")"

# prevent moose abuse
sleep "${MOOSE_SLEEP_TIMER:-5s}"
rmdir "$MOOSE_LOCK" 2>/dev/null
