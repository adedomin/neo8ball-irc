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

MOOSE_URL='https://moose.ghetty.space'

for arg; do
    case "$arg" in
        --reply=*)   reply="${arg#*=}" ;;
        --nick=*)    nick="${arg#*=}" ;;
        --message=*) q="${arg#*=}" ;;
        --command=*) command="${arg#*=}" ;;
        --regexp=*)  regexp="${arg#*=}" ;;
        --match=*)   match="${arg#*=}"
    esac
done
command="${command:-"$regexp"}"
# no-op if not defined.
q="${q#"$match" }"

# moose is verbose and can create a lot of noise
CHANNEL_IN_IGNORE_LIST "$reply" "$MOOSE_IGNORE" && {
    echo ":mn $nick moose command disabled on $reply"
    exit 0
}

SEARCH=
while [[ -n "$q" ]]; do
    arg="${q%% *}"

    case "$arg" in
        -s|--search)
            SEARCH=1
        ;;
        -h|--help)
            echo ":r usage: $command [--search] [query]"
            echo ":r Make Moose @ $MOOSE_URL"
            exit 0
        ;;
        --)
            q="${q#-- }"
            break
        ;;
        '') ;;
        *)
            break
        ;;
    esac

    # Pop arg from query.
    if [[ "${q#"$arg" }" == "$q" ]]; then
        q=
    else
        q="${q#"$arg"* }"
    fi
done

if [[ -n "$SEARCH" ]]; then
    # shellcheck disable=2034
    if [[ -z "$q" ]]; then
        echo ":r search command requires a query"
        exit 0
    fi
    {
        curl --silent --fail "$MOOSE_URL/gallery/newest?p=0&q=$(URI_ENCODE "$q")" ||
            echo '"moose service is down."'
    } | jq \
            -r 'if type == "array" and (. | length) > 0 then
                    ":r Found: \"\u0002" + (
                        map(.name) | join("\u0002\", \"\u0002")
                    ) + "\u0002\"."
                elif type == "string" then
                    ":r \u0002\(.)\u0002"
                else
                    ":r \u0002no moose found.\u0002"
                end
    ' | tr -d '\r\n'
    echo
    exit
fi

MOOSE_LOCK="$PLUGIN_TEMP/moose-lock"

if ! mkdir "$MOOSE_LOCK"; then
    echo ":mn $nick Please wait for the current moose to finish."
    exit 0
fi

printf ':ld -- %s --\n'    curl --location --silent --fail "$MOOSE_URL/irc/$(URI_ENCODE "$q")"
printf ':ld -- %s --\n' "$q" "$(URI_ENCODE "$q")"
{
    curl --location --silent --fail "$MOOSE_URL/irc/$(URI_ENCODE "$q")" ||
        "No such moose: $q"
} | while read -r; do
    printf ":r %s\n" "$REPLY"
    sleep "${MOOSE_SLEEP_DELAY:-0.35s}"
done

# prevent moose abuse
sleep "${MOOSE_SLEEP_TIMER:-5s}"
rmdir "$MOOSE_LOCK" 2>/dev/null
