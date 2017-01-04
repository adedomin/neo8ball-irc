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

VIDME='https://vid.me/api/videos/search?order=hot&query='

RES=$(curl "${VIDME}$(URI_ENCODE "$4")" 2>/dev/null | \
    jq -r '.videos[0],.videos[1],.videos[2] | .full_url + " :: " + .title'
)

IFS=$'\n'
for res in $RES; do
    if [ "$res" = ' :: ' ]; then
        echo ":m $1 no results found"
        exit 0
    fi
    echo ":m $1 $res"
done
