#!/bin/bash
# Copyright 2017 dimattiami, Anthony DeDominic <adedomin@gmail.com>
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
LAST=
msg="$4"
for arg in $4; do
    case "$arg" in
        -c|--count)
            LAST='C'
            msg="${msg#* }"
        ;;
        --count=*)
            echo "${arg#*=}" >&2
            [[ "${arg#*=}" =~ ^[1-3]$ ]] &&
                COUNT="${arg#*=}"
            msg="${msg#* }"
        ;;
        -h|--help)
            echo ":m $1 usage: $5 [--count=#-to-ret] query"
            echp ":m $1 defines a given word."
            exit 0
        ;;
        *)
            [ -z "$LAST" ] && break
            LAST=
            [[ "$arg" =~ ^[1-3]$ ]] &&
                COUNT="$arg"
            msg="${msg#* }"
        ;;
    esac
    if [[ "$msg" == "${msg#* }" ]]; then
        msg=
        break
    else
        msg="${msg#* }"
    fi
done

if [ -z "$msg" ]; then
    echo ":mn $3 This command requires a search query"
    exit 0
fi

DICTIONARY="https://en.wiktionary.org/w/index.php?title=${msg% *}&printable=yes"
declare -i DEF_NUM
DEF_NUM=0

while read -r definition; do
    DEF_NUM+=1
    (( ${#definition} > 400 )) &&
        definition="${definition:0:400}..."
    echo -e ":m $1 "$'\002'"${msg:0:100}\\002 :: $definition"
    (( DEF_NUM >= COUNT )) && break
done < <(
    curl --silent --fail "$DICTIONARY" \
    | xmllint --xpath '/html/body/div/div/div/div/ol/li' - \
    | sed 's@<\(a\|/a\|span\|/span\)[^>]*>@@g' \
    | html2 \
    | sed -n '
        /^\/html\/body\/li=[[:space:]]*$/d
        /^\/html\/body\/li=/ {
          s@/html/body/li=@@p
        }
    ' \
    | head -n 3
)

if (( DEF_NUM > 0 )); then
    echo ":mn $3 See More: $DICTIONARY"
else
    echo ":m $1 No definition found"
fi
