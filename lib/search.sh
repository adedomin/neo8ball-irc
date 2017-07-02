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
            exit 0
        ;;
    esac
done <<< "$6"

if [ -z "$4" ]; then
    echo ":mn $3 This command requires a search query; refer to --help"
    exit 0
fi

URI_DECODE() {
    # change plus to space
    local uri="${1//+/ }"
    # convert % to hex literal and print
    printf '%b' "${uri//%/\\x}"
}

HTML_DECODE() {
    recode -d utf8..html <<< "$1" | recode html..utf8
}

SEARCH_ENGINE="https://duckduckgo.com/html/?q="

while read -r url title; do
    if [ "$title" = 'results.' ] || [ -z "$title" ]; then
        echo ":m $1 No results found"
        exit 0
    fi
    echo -e ":m $1 "$'\002'"$(HTML_DECODE "$title")\002 :: $(URI_DECODE "$url")"
done < <(
    curl "${SEARCH_ENGINE}$(URI_ENCODE "$4")" 2>/dev/null \
    | sed 's@<\([^/a]\|/[^a]\)[^>]*>@@g' \
    | grep -F 'class="result__a"' \
    | grep -Po '(?<=uddg=).*' \
    | sed 's/">/ /;s/<\/a>//' \
    | sed '/r.search.yahoo/d' \
    | head -n "$COUNT"
)
