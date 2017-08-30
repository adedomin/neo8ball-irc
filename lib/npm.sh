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

q="$4"
for arg in $4; do
    case "$arg" in
        -c|--count)
            LAST='c'
            q="${q#* }"
        ;;
        --count=*)
            [[ "${arg#*=}" =~ ^[1-3]$ ]] &&
                COUNT="${arg#*=}"
            q="${q#* }"
        ;;
        -h|--help)
            echo ":m $1 usage: $5 [--count=#-to-ret] query"
            echo ":m $1 search for an npm package."
            exit 0
        ;;
        *)
            [ -z "$LAST" ] && break
            LAST=
            [[ "$arg" =~ ^[1-3]$ ]] &&
                COUNT="$arg"
            q="${q#* }"
        ;;
    esac
done

if [ -z "$q" ]; then
    echo ":mn $3 This command requires a search query, see --help for more info"
    exit 0
fi

NPM="https://www.npmjs.com/-/search?text=$(URI_ENCODE "$q")&from=0&size=${COUNT}"
declare -i DEF_NUM
DEF_NUM=0
 
while read -r name link desc; do
    [ -z "$desc" ] && [ -z "$link" ] && break
    DEF_NUM+=1
    if [ -n "$desc" ]; then
        desc=" $desc ::"
    fi 
    echo -e ":m $1 "$'\002'"${name}\002 ::$desc $link"
done < <(
    curl "$NPM" -f 2>/dev/null |
    jq -r '.objects[0].package,.objects[1].package,.objects[2].package // empty |
        .name + " " + 
        .links.npm + " " + 
        .description
    '
)

(( DEF_NUM < 1 )) && echo ":m $1 No npm module found"
