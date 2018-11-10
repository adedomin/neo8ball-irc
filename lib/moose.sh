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

MOOSE_URL='https://moose.ghetty.space'

# moose is verbose and can create a lot of noise
CHANNEL_IN_IGNORE_LIST "$1" "$MOOSE_IGNORE" && {
    echo ":mn $3 moose command disabled on $1"
    exit 0
}

q="$4"
SEARCH=
for arg in $4; do
    case "$arg" in
        -l|--latest)
            q='latest'
            break
        ;;
        -r|--random)
            q='random'
            break
        ;;
        -s|--search)
            SEARCH=1
        ;;
        -n|--no-shade)
            DISABLE_SHADE=1
        ;;
        -h|--help)
            echo ":m $1 usage: $5 [--latest|--random|--search=page-#|--no-shade] [query]"
            echo ":m $1 Make Moose @ $MOOSE_URL"
            exit 0
        ;;
        --)
            q="${q#*-- }"
            break
        ;;
        *)
            break
        ;;
    esac
    if [[ "$q" == "${q#* }" ]]; then
        q=
        break
    else
        q="${q#* }"
    fi
done

if [[ -n "$SEARCH" ]]; then
    # shellcheck disable=2034
    if [[ -z "$q" ]]; then
        echo ":m $1 search command requires a query"
        exit 0
    fi
    {
        curl --silent --fail "$MOOSE_URL/gallery/newest?p=0&q=$(URI_ENCODE "$q")" ||
            echo '"moose service is down."'
    } | jq --arg CHANNEL "$1" \
            -r 'if type == "array" and (. | length) > 0 then
                    ":m \($CHANNEL) Found: \"\u0002" + (
                        map(.name) | join("\u0002\", \"\u0002")
                    ) + "\u0002\"."
                elif type == "string" then
                    ":m \($CHANNEL) \u0002\(.)\u0002"
                else
                    ":m \($CHANNEL) \u0002no moose found.\u0002"
                end
    ' | tr -d '\r\n'
    echo
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
['0']="00"
['1']="01"
['2']="02"
['3']="03"
['4']="04"
['5']="05"
['6']="06"
['7']="07"
['8']="08"
['9']="09"
['a']="10"
['b']="11"
['c']="12"
['d']="13"
['e']="14"
['f']="15"
)

declare -A SHADERS
SHADERS=(
['0']=',00░'
['1']=',00▒'
['2']=',00▓'
['3']='█'
['4']=',01▓'
['5']=',01▒'
['6']=',01░'
)

# get moose and moose meta data
MOOSE="$(
    curl "$MOOSE_URL/moose/$(URI_ENCODE "${q:-random}")" 2>/dev/null
)"
MOOSE_ERR="$(jq -r '.status' <<< "$MOOSE")"
# check for error
if [[ "$MOOSE_ERR" == 'error' || -z "$MOOSE" ]]; then
    echo ":m $1 404 - Make it @ $MOOSE_URL/#?edit=$(URI_ENCODE "$4")"
    rmdir "$MOOSE_LOCK" 2>/dev/null
    exit 0
fi
# extract name
MOOSE_NAME="$(jq -r '.name' <<< "$MOOSE")"
MOOSE_DATE="$(jq -r '.created' <<< "$MOOSE")"
[[ -z "$DISABLE_SHADE" ]] &&
    MOOSE_SHADED="$(jq -r '.shaded' <<< "$MOOSE")"
MOOSE_IMAGE=()
while read -r line; do
    MOOSE_IMAGE+=("$line")
done < <(
    jq -r '.image' <<< "$MOOSE"
)

MOOSE_SHADING=()
if [[ "$MOOSE_SHADED" = 'true' ]]; then
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
    if [[ -z "$line" ]]; then
        unset MOOSE_IMAGE'[i]'
        [[ "$MOOSE_SHADED" == 'true' ]] &&
            unset MOOSE_SHADING'[i]'
    else
        break
    fi
done

# have to rebuild array due to how unsetting deletes positions
MOOSE_IMAGE=("${MOOSE_IMAGE[@]}")
MOOSE_SHADING=("${MOOSE_SHADING[@]}")

# trim moose image
#check from down up
for (( i=${#MOOSE_IMAGE[@]}; i>=0; i-- )); do
    line="${MOOSE_IMAGE[i]}"
    line="${line//t}"
    line="${line// }"
    if [[ -z "$line" ]]; then
        unset MOOSE_IMAGE'[i]'
        [[ "$MOOSE_SHADED" == 'true' ]] &&
            unset MOOSE_SHADING'[i]'
    else
        break
    fi
done

# have to rebuild array due to how unsetting deletes positions
MOOSE_IMAGE=("${MOOSE_IMAGE[@]}")
MOOSE_SHADING=("${MOOSE_SHADING[@]}")

# trim from left to right
for (( i=0; i<${#MOOSE_IMAGE}; i++ )); do
    for (( j=0; j<${#MOOSE_IMAGE[@]}; j++ )); do
        line="${MOOSE_IMAGE[j]}"
        if [[ "${line:0:1}" != 't' ]]; then
            noleft=1
            break
        fi
    done
    [[ -n "$noleft" ]] && break
    for (( j=0; j<${#MOOSE_IMAGE[@]}; j++ )); do
        line="${MOOSE_IMAGE[j]}"
        MOOSE_IMAGE[j]="${line:1}"
        if [[ "$MOOSE_SHADED" = 'true' ]]; then
            sline="${MOOSE_SHADING[j]}"
            MOOSE_SHADING[j]="${sline:1}"
        fi
    done
done
unset noleft

# trim from right to left
for (( i=0; i<${#MOOSE_IMAGE}; i++ )); do
    for (( j=0; j<${#MOOSE_IMAGE[@]}; j++ )); do
        line="${MOOSE_IMAGE[j]}"
        if [[ "${line: -1}" != 't' ]]; then 
            noleft=1
            break
        fi
    done
    [[ -n "$noleft" ]] && break
    for (( j=0; j<${#MOOSE_IMAGE[@]}; j++ )); do
        line="${MOOSE_IMAGE[j]}"
        MOOSE_IMAGE[$j]="${line:0:-1}"
        if [[ "$MOOSE_SHADED" = 'true' ]]; then
            sline="${MOOSE_SHADING[j]}"
            MOOSE_SHADING[j]="${sline:0:-1}"
        fi
    done
done

[[ "$MOOSE_SHADED" == 'true' ]] && declare -i shade_lineno
[[ "$MOOSE_SHADED" != 'true' ]] && symbol="${SHADERS['3']}"
for line in "${MOOSE_IMAGE[@]}"; do
    out=''
    [[ "$MOOSE_SHADED" = 'true' ]] &&
        shade_line="${MOOSE_SHADING[shade_lineno]}"
    for (( i=0; i<${#line}; i++ )); do
        if [ "${line:$i:1}" = 't' ]; then
            out+=' '
        else
            color="${COLOR["${line:$i:1}"]}"
            if [[ "$MOOSE_SHADED" = 'true' ]]; then
                shade="${shade_line:$i:1}"
                symbol="${SHADERS[$shade]}"
                [[ "$shade" = '3' ]] && color+=",$color"
            else
                color+=",$color"
            fi
            out+="${KCOL}${color}${symbol}${KCOL}"
        fi
    done
    echo -e ":m $1 \\u200B$out"
    shade_lineno+=1
    sleep "0.3s"
done
outstring=""
if [[ "$q" = 'latest' || "${q:-random}" = 'random' ]]; then
    outstring+=$'\002'"$MOOSE_NAME"$'\002'" -"
fi
echo ":m $1 $outstring Created $(reladate "$MOOSE_DATE")"

# prevent moose abuse
sleep "${MOOSE_SLEEP_TIMER:-5s}"
rmdir "$MOOSE_LOCK" 2>/dev/null
