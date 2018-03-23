#!/usr/bin/env bash
# Copyright 2017 Anthony DeDominic <adedomin@gmail.com>
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

VOTE_LOCK="$PLUGIN_TEMP/${1//\//|}-vote"
YES="$VOTE_LOCK/yes"
NO="$VOTE_LOCK/no"
ISSUE="$VOTE_LOCK/issue"
DURATION="120"

# $1 - channel name
standings() {
    yes="$(wc -l < "$YES")"
    no="$(wc -l  < "$NO")"
    echo -e ":m $1 Yes "$'\003'"03${yes:-0}"
    echo -e ":m $1 No  "$'\003'"04${no:-0}"
}

# parse args
v="$4"
for key in $4; do
    case "$key" in
        -d|--duration)
            LAST='d'
        ;;
        --duration=*)
            DURATION="${key#*=}" 
            [[ "$DURATION" =~ ^[0-9]*$ ]] || 
                DURATION=120
            (( DURATION > 30 && DURATION < 3601 )) || 
                DURATION=120
        ;;
        -h|--help)
            echo ":m $1 usage: $5 [--duration=#] <y/n question>"
            echo ":m $1 create a vote for a given question."
            echo ":m $1 duration option must be between 30 to 3600 seconds."
            exit 0
        ;;
        *)
            [ -z "$LAST" ] && break
            LAST=
            if [[ "$key" =~ ^[0-9]*$ ]]; then
                (( key > 30 && key < 3601 )) &&
                    DURATION="$key"
            fi
        ;;
    esac
    if [[ "$v" == "${v#* }" ]]; then
        v=
        break
    else
        v="${v#* }"
    fi
done

if [ ! -d "$VOTE_LOCK" ] && [ "$5" != 'vote' ]; then
    echo ":m $1 No vote in progress; please use .vote question"
    exit 0
fi

if [ "$5" = 'standings' ]; then
    echo -e ":m $1 \\002Current Standings\\002 $(< "$ISSUE")"
    standings "$1"
    exit 0
fi

if [ "$5" != 'vote' ] && 
    grep -q -F "$2" "$YES" "$NO" 2>/dev/null
then
    echo ":mn $3 You have already voted."
    exit 0
fi

if [ "$5" = 'vote' ]; then
    if ! mkdir "$VOTE_LOCK" 2>/dev/null; then
        echo ":m $1 A vote is already in progress."
        exit 0
    fi
    echo "$v" > "$ISSUE"

    echo ":m $1 A vote on the issue ( ${v:0:200} ) has started and will finish in $DURATION seconds."
    echo -e ":m $1 Use \\002.yes\\002 or \\002.no\\002 to vote;" \
        "\\002.standings\\002 to view current results."

    sleep "${DURATION}s"
    echo -e ":m $1 \\002Vote results\\002 $v"
    standings "$1"
    rm -rf -- "$VOTE_LOCK"

elif [ "$5" = 'yes' ]; then
    echo "$2" >> "$YES"
    echo -e ":mn $3 Your \\002yes\\002 vote was cast."

elif [ "$5" = 'no' ]; then
    echo "$2" >> "$NO"
    echo -e ":mn $3 Your \\002no\\002 vote was cast."
fi
