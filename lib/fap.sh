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
LAST=
declare -i AMT_RESULTS
AMT_RESULTS=1
for arg in $4; do
    case "$arg" in
        -c|--count)
            LAST='C'
        ;;
        --count=*)
            [[ "${arg#*=}" =~ ^[1-3]$ ]] &&
                AMT_RESULTS="${arg#*=}"
        ;;
        -h|--help)
            echo ":m $1 usage: $5 [--count=#-to-ret] [query]"
            echo ":m $1 search for pornographic material or let the bot output a random one."
            exit 0
        ;;
        *)
            [ -z "$LAST" ] && break
            LAST=
            [[ "$arg" =~ ^[1-3]$ ]] &&
                AMT_RESULTS="$arg"
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
    q="$(
        curl -s "https://www.pornmd.com/randomwords?orientation=$orientation" \
        | tr -d '"'
    )"
fi
PORN_MD="https://www.pornmd.com"
# query must be lowercase, non lowercase queries cause weirdness
PORN_MD_SRCH="$PORN_MD/$orientation/$(URI_ENCODE "${q,,}")"

while read -r uri title; do
    [ -z "$title" ] && exit
    url="$(
        curl "$PORN_MD$uri" -I 2>/dev/null \
        | sed -ne 's/^Location: //ip'
    )"
    title="$(
        HTML_CHAR_ENT_TO_UTF8 <<< "$title"
    )"
    echo -e ":m $1 "$'\002'"${title}\002 :: ${url}"
done < <(
    # changes seem to create duplicates
    # stupid uniq isn't removing the uniqes either
    # despite the fact they are adjacent
    curl "$PORN_MD_SRCH" 2>/dev/null \
    | sed 's@<\([^/a]\|/[^a]\)[^>]*>@@g'  \
    | grep -Po '(?<=href=")[^"]*|(?<=title=")[^"]*' \
    | grep -F -A 1 -m "$(( AMT_RESULTS * 2 ))" '/viewvideo' \
    | sed -e '/--/d' -e 'N;s/\n/ /' \
    | sed -e '1~2d'
)
