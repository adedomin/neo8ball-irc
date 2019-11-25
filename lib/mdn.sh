#!/bin/bash
# Copyright 2018 Anthony DeDominic <adedomin@gmail.com>
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
COUNT=1
TOPIC=

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
        -t|--topic)
            LAST=t
        ;;
        --topic=*)
            TOPIC='&topic='"$(URI_ENCODE "${arg#*=}")"
        ;;
        -h|--help)
            echo ":m $1 usage: $5 [--topic=topic-on-mdn] [--count=#-to-ret] query"
            echo ":m $1 search MDN for javascript/web information."
            exit 0
        ;;
        *)
            [ -z "$LAST" ] && break
            case "$LAST" in
                c)
                    [[ "$arg" =~ ^[1-3]$ ]] &&
                        COUNT="$arg"
                ;;
                t)
                    TOPIC='&topic='"$(URI_ENCODE "$arg")"
                ;;
            esac
            LAST=

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
    echo ":mn $3 This command requires a search query, see --help for more info"
    exit 0
fi

mdn_search='https://developer.mozilla.org/api/v1/search/en-US?q='"$(URI_ENCODE "$q")""$TOPIC"

{
    curl --silent \
        --fail \
        "$mdn_search" || echo null
} | jq \
    --arg COUNT "$COUNT" \
    --arg CHANNEL "$1" \
    --arg BOLD $'\002' \
    --arg MDN_LOCATION 'https://developer.mozilla.org/' \
    -r 'if (.documents[0]) then
            .documents[0:($COUNT | tonumber)][]
    else
        { title: "No Results", excerpt: "", url: "" }
    end
    | ":m \($CHANNEL) \($BOLD)" + .title + $BOLD +
      " " + (.excerpt | gsub("</?mark>"; ""))[0:200] + " :: " +
      \($MDN_LOCATION) + .slug
'
