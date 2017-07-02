#!/usr/bin/env bash
# Copyright 2017 QUiNTZ & prussian
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

orientation='straight'
if [ "$5" = 'gay' ]; then
    orientation='gay'
fi

q="$4"
if [ -z "$q" ]; then
    q="$(curl "https://www.pornmd.com/randomwords?orientation=$orientation" 2>/dev/null | tr -d '"' )"
fi

declare -i AMT_RESULTS
AMT_RESULTS=1

# parse args
while IFS='=' read -r key val; do
    case "$key" in
        -c|--count)
            [[ "$val" =~ ^[1-3]$ ]] &&
                AMT_RESULTS="$val"
        ;;
        -h|--help)
            echo ":m $1 usage: $5 [--count=#-to-ret] [query]"
            echo ":m $1 search for pornographic material or let the bot output a random one."
            exit 0
        ;;
    esac
done <<< "$6"

PORN_MD="https://www.pornmd.com"
PORN_MD_SRCH="$PORN_MD/$orientation/$(URI_ENCODE "${q,,}")"

while read -r uri title; do
    [ -z "$title" ] && exit
    url="$(
        curl "$PORN_MD$uri" -I 2>/dev/null \
        | sed -ne 's/^Location: //ip' 
    )"
    title="$(
        recode -d utf8..html <<< "$title" \
        | recode html..utf8
    )"
    echo -e ":m $1 "$'\002'"${title}\002 :: ${url}"
done < <(
    curl "$PORN_MD_SRCH" 2>/dev/null \
    | sed 's@<\([^/a]\|/[^a]\)[^>]*>@@g'  \
    | grep -Po '(?<=href=")[^"]*|(?<=title=")[^"]*' \
    | grep -F -A 1 -m "$AMT_RESULTS" '/viewvideo' \
    | sed -e '/--/d' -e 'N;s/\n/ /'
)
