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

declare -i COUNT
COUNT=3

# parse args
while IFS='=' read -r key val; do
    case "$key" in
        -c|--count)
            [[ "$val" =~ ^[1-3]$ ]] &&
                COUNT="$val"
        ;;
        -h|--help)
            echo ":m $1 usage: $5 [--count=#-to-ret] query"
            echo ":m $1 find a wikipedia article."
            exit 0
        ;;
    esac
done <<< "$6"

if [ -z "$4" ]; then
    echo ":mn $3 This command requires a search query"
    exit 0
fi

WIKI="https://en.wikipedia.org/w/api.php?action=opensearch&format=json&formatversion=2&search=$(URI_ENCODE "$4")&namespace=0&limit=${COUNT}&suggest=false"
declare -i DEF_NUM
DEF_NUM=0

while read -r link name; do
    [ -z "$name" ] && break
    DEF_NUM+=1
    echo -e ":m $1 "$'\002'"${name}\002 :: $link"
done < <( 
    curl -f "$WIKI" 2>/dev/null \
    | jq -r '[.[1],.[3]] // empty 
        | transpose 
        | map(.[1] + " " + .[0]) 
        | .[]
    ' 
)

if (( DEF_NUM < 1 )); then
    echo ":m $1 No results"
fi
