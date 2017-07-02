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
red=$'\003'"04"
green=$'\003'"03"

declare -i COUNT
COUNT=3

# parse args
while IFS='=' read -r key val; do
    case "$key" in
        -c|--count)
            [[ "$val" =~ ^[1-4]$ ]] &&
                COUNT="$val"
        ;;
        -h|--help)
            echo ":m $1 usage: $5 [--count=#-to-ret] query"
            exit 0
        ;;
    esac
done <<< "$6"

if [ -z "$4" ]; then
    echo ":mn $3 This command requires a search query"
    exit 0
fi

VIDME='https://vid.me/api/videos/search?order=score&query='
declare -i DEF_NUM
DEF_NUM=0

while read -r url duration views likes title; do
    [ -z "$title" ] && break
    DEF_NUM+=1
    min="$(bc <<< "scale=0; $duration / 60")"
    sec="$(bc <<< "scale=0; ($duration % 60)/1")"
    echo -e ":m $1 "$'\002'"${title}\002 (${min}m${sec}s) ::" \
        "\002Views\002 ${red}$(printf "%'d" "$views")\003 ::" \
        "\002Likes\002 ${green}$(printf "%'d" "$likes")\003 ::" \
        "\002URL\002 $url"
    (( DEF_NUM >= COUNT )) && break
done < <(
    curl "${VIDME}$(URI_ENCODE "$4")" 2>/dev/null | \
    jq -r '.videos[0],.videos[1],.videos[2],.videos[3] // empty |
        .full_url + " " + 
        (.duration|tostring) + " " + 
        (.view_count|tostring) + " " + 
        (.likes_count|tostring) + " " + 
        .title
    '
)

if (( DEF_NUM < 1 )); then
    echo ":m $1 No results"
fi
