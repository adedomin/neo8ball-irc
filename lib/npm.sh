#!/usr/bin/env bash
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
COUNT=3

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
        -h|--help)
            echo ":m $1 usage: $5 [--count=#-to-ret] query"
            echo ":m $1 search for an npm package."
            exit 0
        ;;
        *)
            [ -z "$LAST" ] && break
            LAST=
            [[ "$arg" =~ ^[1-3]$ ]] &&
                COUNT="$arg"
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

NPM="https://www.npmjs.com/-/search?text=$(URI_ENCODE "$q")&from=0&size=${COUNT}"

{
    curl \
        --silent \
        --fail "$NPM" \
    || echo null
} | jq -r --arg BOLD $'\002' \
        --arg CHANNEL "$1" \
        --arg COUNT "$COUNT" '
    if (.objects[0]) then
        .objects[0:($COUNT | tonumber)][]
    else
        {
          package: {
            name: "No npm module found"
            , links: { npm: "" }
            , description: ""
          }
      }
    end
    | .package
    | ":m \($CHANNEL) \($BOLD)" + .name + $BOLD +
      " " + .links.npm + " " +
      .description[0:150]
'
