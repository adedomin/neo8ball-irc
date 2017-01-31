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

read -r sub sortt <<< "$4"

if [ -n "$sub" ]; then
    sub="r/${sub}/"
fi
if [ -z "$sortt" ]; then
    sortt="hot"
fi
case $sortt in
    top|best|controversial|new|hot) 
        sortt="${sortt}"
    ;;
    *) 
       echo ":m $1 Invalid sort type: must be <top|best|controversial|new|hot>"
       exit 0 
    ;;
esac

IFS=$'='
while read -r key value; do
    case $key in
        *entry/link/@href)
            HREF="$value"
        ;;
        *entry/title)
            echo -e ":m $1 \002${value}\002 :: $HREF"
        ;;
    esac
done < <(
    curl "https://www.reddit.com/${sub}${sortt}/.xml?limit=3" \
        -H 'Host: www.reddit.com' \
        -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/57.0.2704.103 Safari/537.36' \
        -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' \
        -H 'Accept-Language: en-US,en;q=0.5' \
        --compressed \
        -H 'Connection: keep-alive' \
        -H 'Upgrade-Insecure-Requests: 1' \
        -H 'Cache-Control: max-age=0' \
        2>/dev/null |
    xml2
)
