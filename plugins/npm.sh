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
COUNT=1

for arg; do
    case "$arg" in
        --nick=*)    nick="${arg#*=}" ;;
        --message=*) q="${arg#*=}" ;;
        --command=*) command="${arg#*=}" ;;
    esac
done

while [[ -n "$q" ]]; do
    arg="${q%% *}"

    case "$arg" in
        -c|--count)
            LAST='c'
        ;;
        --count=*)
            [[ "${arg#*=}" =~ ^[1-3]$ ]] &&
                COUNT="${arg#*=}"
        ;;
        -h|--help)
            echo ":r usage: $command [--count=#-to-ret] query"
            echo ":r search for an npm package."
            exit 0
        ;;
        '') ;;
        *)
            [ -z "$LAST" ] && break
            LAST=
            [[ "$arg" =~ ^[1-3]$ ]] &&
                COUNT="$arg"
        ;;
    esac

    if [[ "${q#"$arg" }" == "$q" ]]; then
        q=
    else
        q="${q#"$arg" }"
    fi
done

if [[ -z "$q" ]]; then
    echo ":mn $nick This command requires a search query, see --help for more info"
    exit 0
fi

NPM="https://www.npmjs.com/search/suggestions?q=$(URI_ENCODE "$q")&size=${COUNT}"

{
    curl \
        --silent \
        --fail "$NPM" \
    || echo null
} | jq -r --arg BOLD $'\002' \
        --arg COUNT "$COUNT" '
    if (.[0]) then
        .[0:($COUNT | tonumber)][]
    else
      {
        name: "No npm module found"
        , links: { npm: "" }
        , description: ""
      }
    end
    | ":r \($BOLD)" + .name + $BOLD +
      " " + .links.npm + " " +
      .description[0:150]
'
