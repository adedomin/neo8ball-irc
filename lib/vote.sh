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
BOLD=$'\002'
COLOR=$'\003'

# $1 - user
already_vote_check() {
    grep -q -F -- "$1" "$YES" "$NO" && {
        printf '%s\n' ":mn $3 You have already voted."
        exit 0
    }
}

# $1 - channel name
standings() {
    yes="$(wc -l < "$YES")"
    no="$(wc -l  < "$NO")"
    printf '%s\n' ":m $1 Yes ${COLOR}03${yes:-0}" \
                  ":m $1 No  ${COLOR}04${no:-0}"
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
            printf '%s\n' \
                ":m $1 usage: $5 [--duration=#] <y/n question>" \
                ":m $1 create a vote for a given question." \
                ":m $1 duration option must be between 30 to 3600 seconds."
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

if [[ ! -d "$VOTE_LOCK" && "$5" != 'vote' ]]; then
    printf '%s\n' ":m $1 No vote in progress; please use .vote question"
    exit 0
fi

case "$5" in
    standings)
        printf '%s\n' \
            ":m $1 ${BOLD}Current Standings${BOLD} $(< "$ISSUE")"
        standings "$1"
        exit 0
    ;;
    vote)
        if ! mkdir "$VOTE_LOCK" 2>/dev/null; then
            printf '%s\n' ":m $1 A vote is already in progress."
            exit 0
        fi
        printf '%s\n' "$v" > "$ISSUE"

        printf '%s %s\n' \
            ":m $1 A vote on the issue ( ${v:0:200} ) has started and" \
            "will finish in $DURATION seconds."
        printf '%s %s\n' \
            ":m $1 Use ${BOLD}.yes${BOLD} or ${BOLD}.no${BOLD} to vote;" \
            "${BOLD}.standings${BOLD} to view current results."

        sleep "${DURATION}s"
        printf '%s\n' ":m $1 ${BOLD}Vote results${BOLD} $v"
        standings "$1"
        rm -rf -- "$VOTE_LOCK"
    ;;
    yes)
        already_vote_check "$2"
        printf '%s\n' "$2" >> "$YES"
        printf '%s\n' ":mn $3 Your ${BOLD}yes${BOLD} vote was cast."
    ;;
    no)
        already_vote_check "$2"
        printf '%s\n' "$2" >> "$NO"
        printf '%s\n' ":mn $3 Your ${BOLD}no${BOLD} vote was cast."
    ;;
esac
