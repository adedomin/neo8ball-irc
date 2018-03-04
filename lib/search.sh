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

q="$4"
for arg in $4; do
    case "$arg" in
        -c|--count)
            LAST='c'
        ;;
        --count=*)
            [[ "${arg#*=}" =~ ^[1-3]$ ]] &&
                COUNT="${arg#*=}"
        ;;
        -h|--help)
            echo ":m $1 usage: $5 [--count=#-to-ret] query"
            echo ":m $1 search duckduckgo for whatever your heart desires."
            exit 0
        ;;
        *)
            [ -z "$LAST" ] && break
            LAST=
            [[ "$arg" =~ ^[1-3]$ ]] &&
                COUNT="$arg"
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
    echo ":mn $3 This command requires a search query; refer to --help"
    exit 0
fi

URI_DECODE() {
    # change plus to space
    local uri="${1//+/ }"
    # convert % to hex literal and print
    printf '%b' "${uri//%/\\x}"
}

SEARCH_ENGINE="https://duckduckgo.com/html/?q="

while read -r url title; do
    if [ "$title" = 'results.' ] || [ -z "$title" ]; then
        echo ":m $1 No results found"
        exit 0
    fi
    echo -e ":m $1 "$'\002'"$(HTML_CHAR_ENT_TO_UTF8 <<< "$title")\002 :: $(URI_DECODE "$url")"
done < <(
    curl --silent \
        --fail \
        "${SEARCH_ENGINE}$(URI_ENCODE "$q")" \
    | sed 's@<\([^/a]\|/[^a]\)[^>]*>@@g' \
    | grep -F 'class="result__a"' \
    | grep -Po '(?<=uddg=).*' \
    | sed 's/">/ /;s/<\/a>//' \
    | sed '/r.search.yahoo/d' \
    | head -n "$COUNT"
)
