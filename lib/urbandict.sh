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

declare -i COUNT
COUNT=3

# parse args
q="$4"
for key in $4; do
    case "$key" in
        -c|--count)
            LAST='c'
        ;;
        --count=*)
            [[ "${key#*=}" =~ ^[1-3]$ ]] &&
                COUNT="${key#*=}"
        ;;
        -d|--definition)
            LAST='d'
        ;;
        --definition=*)
            [[ "${key#*=}" =~ ^(1[0-9]|[1-9])$ ]] &&
                DEFINITION="${key#*=}"
        ;;
        -h|--help)
            echo ":m $1 usage: $5 [--count=#-to-ret|--definition=#] query"
            echo ":m $1 find a defintion for a word using the urban dictionary."
            exit 0
        ;;
        *)
            [ -z "$LAST" ] && break
            if [ "$LAST" = 'd' ]; then
                declare -i DEFINITION
                [[ "$key" =~ ^(1[0-9]|[1-9])$ ]] &&
                    DEFINITION="$key"
            else
                [[ "$key" =~ ^[1-3]$ ]] &&
                    COUNT="$key"
            fi
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

if [ -z "$4" ]; then
    echo ":mn $3 This command requires a search query"
    exit 0
fi

# kept for advert
URBAN="http://www.urbandictionary.com/define.php?term=$(URI_ENCODE "$q")"
NEW_URBAN="http://api.urbandictionary.com/v0/define?term=$(URI_ENCODE "$q")"

{
    curl \
        --silent \
        --fail \
        --location \
        "$NEW_URBAN" \
    || echo null
} | jq  --arg BOLD $'\002' \
        --arg CHANNEL "$1" \
        --arg COUNT "$COUNT" \
        --arg DEFNUM "$DEFINITION" \
        --arg WORD "$q" \
        -r '
    if ($DEFNUM != "") then
        if (.list[($DEFNUM | tonumber) - 1]) then
            .list[($DEFNUM | tonumber) - 1]
        else
            { definition: "No Definition Found." }
        end
    else
        if (.list[0]) then
            .list[0:($COUNT | tonumber)][]
        else
            { definition: "No Definition Found." }
        end
    end
    | ":m \($CHANNEL) \($BOLD)\($WORD)\($BOLD) :: \(.definition[0:400])"
    | sub("\r|\n"; " "; "g")
    | sub("  +"; " "; "g")
'

echo ":mn $3 See More: $URBAN"
