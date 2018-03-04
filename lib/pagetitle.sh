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

# parse args
URL="$6"

while read -r key val; do
    case ${key,,} in
        content-type:)
            mime="${val%$'\r'}"
            mime="${mime%%;*}"
        ;;
        content-length:)
            sizeof="$(numfmt --suffix='B' --to=iec-i "${val%$'\r'}")"
        ;;
    esac
done < <(
    curl -s -L --max-redirs 2 -m 10 -I "$URL"
)

[ -z "$mime" ] && exit 0 

if [[ "$mime" == image/* ]] && 
    [ -n "$MS_COG_SERV" ] && 
    [ -n "$MS_COG_KEY" ]
then
    read -r dimension confidence caption < <(
        curl -f "$MS_COG_SERV" \
            -H 'Content-Type: application/json' \
            -H "Ocp-Apim-Subscription-Key: $MS_COG_KEY" \
            -d '{ "url": '"\"$URL\""' }' \
            2>/dev/null \
        | jq -r '(.metadata.height|tostring) + "x"
            + (.metadata.width|tostring) + " "
            + (.description.captions[0].confidence*100|floor|tostring) + " "
            + .description.captions[0].text'
    )
    echo -e ":m $1 ↑ \002Image\002 :: $mime (${dimension:-0x0} ${sizeof:-Unknown B}) :: \002Description\002 ${caption:-unknown error} :: \002Confidence\002 ${confidence:-0}%"
    exit 0
fi

if [[ ! "$mime" =~ text/html|application/xhtml+xml ]]; then
    [ -n "$PAGETITLE_DISABLE_FILE" ] && exit
    echo -e ":m $1 ↑ \002File\002 :: $mime (${sizeof:-Unknown})"
    exit 0
fi

{
    printf '%s' ":m $1 ↑ \002Title\002 :: "
    curl --silent \
        --fail \
        --compressed \
        --location \
        --max-redirs 2 \
        --max-time 10 \
        "$URL" \
    | sed -n '
        /<title[^>]*>.*<\/title>/I {
          s@.*<title[^>]*>\(.*\)</title>.*@\1@Ip
          q
        }
        /<title[^>]*>/I {
          :next
          N
          /<\/title>/I {
            s@.*<title[^>]*>\(.*\)</title>.*@\1@Ip
            q
          }
          $! b next
        }' \
    | HTML_CHAR_ENT_TO_UTF8 \
    | tr '\r\n' ' '
    echo
}
