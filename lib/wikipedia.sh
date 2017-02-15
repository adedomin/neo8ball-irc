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

if [ -z "$4" ]; then
    echo ":mn $3 This command requires a search query"
    exit 0
fi

URI_ENCODE() {
    curl -Gso /dev/null \
        -w '%{url_effective}' \
        --data-urlencode @- '' <<< "$1" | \
    cut -c 3-
}

ARG="$(URI_ENCODE "$4")"
ARG="${ARG%\%0A}"
WIKI="https://en.wikipedia.org/w/api.php?action=opensearch&format=json&formatversion=2&search=${ARG}&namespace=0&limit=3&suggest=false"

while read -r link name; do
    echo -e ":m $1 \002${name}\002 :: $link"
done < <( curl -f "$WIKI" 2>/dev/null | jq -r '[.[1],.[3]] // empty | transpose | map(.[1] + " " + .[0]) | .[]' )
