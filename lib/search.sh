#!/usr/bin/env bash
# Copyright 2016 prussian <genunrest@gmail.com>
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

SEARCH_ENGINE="https://duckduckgo.com/html/?q="

while read -r url title; do
    [ -z "$title" ] && exit 0
    echo -e ":m $1 \002${title}\002 :: $url"
done < <(
    curl "${SEARCH_ENGINE}$(URI_ENCODE "$4")" 2>/dev/null | \
    sed 's@</*b>@@g' | \
    html2 2>/dev/null | \
    grep -A 2 "@class=result__a" | \
    sed '/^--$/d' | \
    sed '/@class/d' | \
    grep -Po '(?<=\/a(=|\/)).*' | \
    paste -d " " - - | \
    sed 's/\(@href\|b\)=//g' | \
    sed '/r\.search\.yahoo\.com/d' | \
    head -n 3
)
