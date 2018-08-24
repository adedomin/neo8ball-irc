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

declare -i COUNT
COUNT=1

# parse args
q="$4"
for key in $4; do
    case "$key" in
        -c|--count)
            LAST='c'
        ;;
        --count=*)
            [[ "${key#*=}" =~ ^[1-3]$ ]] &&
                COUNT="${key#*=}"
        ;;
        -h|--help)
            echo ":m $1 usage: $5 [--count=#-to-ret] query"
            echo ":m $1 find a wikipedia article."
            exit 0
        ;;
        *)
            [ -z "$LAST" ] && break
            LAST=
            [[ "$key" =~ ^[1-3]$ ]] &&
                COUNT="$key"
        ;;
    esac
    if [[ "$q" == "${q#* }" ]]; then
        q=
        break
    else
        q="${q#* }"
    fi
done

if [ -z "$q" ]; then
    echo ":mn $3 This command requires a search query"
    exit 0
fi

WIKI="https://en.wikipedia.org/w/api.php?action=opensearch&format=json&formatversion=2&search=$(URI_ENCODE "$q")&namespace=0&limit=${COUNT}&suggest=false"

{
    curl --silent \
        --fail "$WIKI" \
    || echo null
} | jq --arg CHAN "$1" \
       --arg COUNT "$COUNT" \
       -r '
    if ((.[1] | length) > 0) then
        [.[1][0:($COUNT | tonumber)],.[2][0:($COUNT | tonumber)],.[3][0:($COUNT | tonumber)]]
        | transpose
        | map(":m \($CHAN) \u0002\(.[0])\u0002 :: \(.[2]) :: \(.[1][0:360])")
        | .[]
    else
        ":m \($CHAN) No Results."
    end
'
