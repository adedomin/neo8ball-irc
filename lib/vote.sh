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

VOTE_LOCK="$PLUGIN_TEMP/${1}-vote"
DURATION="120"

# parse args
while IFS='=' read -r key val; do
    case "$key" in
        -d|--duration)
            if [[ "$val" =~ ^[0-9]*$ ]]; then
                (( val > 0 && val < 361 )) &&
                    DURATION="$val"
            fi
        ;;
        -h|--help)
            echo ":m $1 usage: $5 [--duration=#] <y/n question>"
            echo ":m $1 create a vote for a given question."
            exit 0
        ;;
    esac
done <<< "$6"

if [ ! -d "$VOTE_LOCK" ] && [ "$5" != 'vote' ]; then
    echo ":m $1 No vote in progress; please use .vote question"
    exit 0
fi

if [ "$5" = 'vote' ]; then
    if ! mkdir "$VOTE_LOCK" 2>/dev/null; then
        echo ":m $1 A vote is already in progress."
        exit 0
    fi
    echo ":m $1 A vote on the issue ( ${4:0:200} ) has started and will finish in $DURATION seconds."
    echo -e ":m $1 Use \002.yes\002 or \002.no\002 to vote."
    sleep "${DURATION}s"
    yes="$(wc -l < "$VOTE_LOCK/yes")"
    no="$(wc -l  < "$VOTE_LOCK/no")"
    rm -rf -- "$VOTE_LOCK"
    echo -e ":m $1 \002Vote results\002 $4"
    echo -e ":m $1 Yes "$'\003'"03${yes:-0}"
    echo -e ":m $1 No  "$'\003'"04${no:-0}"
elif [ "$5" = 'yes' ]; then
    if grep -q -F "$2" "$VOTE_LOCK/yes" 2>/dev/null; then
        echo ":mn $3 You have already voted."
        exit 0
    fi
    echo "$2" >> "$VOTE_LOCK/yes"
elif [ "$5" = 'no' ]; then
    if grep -q -F "$2" "$VOTE_LOCK/no" 2>/dev/null; then
        echo ":mn $3 You have already voted."
        exit 0
    fi
    echo "$2" >> "$VOTE_LOCK/no"
fi
