#!/bin/bash
# Copyright 2017 dimattiami, prussian <genunrest@gmail.com>
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

URI_ENCODE() {
    curl -Gso /dev/null \
        -w '%{url_effective}' \
        --data-urlencode @- '' <<< "$1" | \
    cut -c 3-
}

echo "http://www.dictionary.com/browse/$(URI_ENCODE "$4")" |
    wget -O- -i- --quiet | 
    hxnormalize -x 2>/dev/null | 
    hxselect -i "div.def-set" 2>/dev/null |  
    lynx -stdin -dump 2>/dev/null |
    xargs 2>/dev/null |
    sed 's/[0-9]\./\n&/g' |
    head -n 4 |
    sed '/^$/d' |
while read -r definition; do
    echo ":m $1 $definition"
done
