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

while read -r key val; do
    case ${key,,} in
        content-type:)
            mime="${val%$'\r'}"
            mime="${mime%%;*}"
        ;;
        content-length:)
            sizeof="$(numfmt --to=iec-i "${val%$'\r'}")"
        ;;
    esac
done < <(
    curl -L --max-redirs 2 -m 10 -I "$5" 2>/dev/null
)

[ -z "$mime" ] && exit 0 
if [[ ! "$mime" =~ text/html|application/xhtml+xml ]]; then
    echo -e ":m $1 ↑ \002File\002 :: $mime (${sizeof}B)"
    exit 0
fi


read -rd '' title < <(
    curl --compressed -L --max-redirs 2 -m 10 "$5" 2>/dev/null | tr -d $'\r' |sed -n '
        /<title[^>]*>.*<\/title>/I {
          s@.*<title[^>]*>\(.*\)</title>.*@\1@Ip
          d
          q
        }
        /<title[^>]*>/I {
          :next
          N
          /<\/title>/I {
            s@.*<title[^>]*>\(.*\)</title>.*@\1@Ip
            d
            q
          }
          $! b next
        }' | 
    recode -d utf8..html | recode html..utf8 | tr $'\n' ' '
)
echo -e ":m $1 ↑ \002Title\002 :: $title"
