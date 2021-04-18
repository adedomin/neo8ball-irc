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

for arg; do
    case "$arg" in
        --reply=*)   reply="${arg#*=}" ;;
        --nick=*)    nick="${arg#*=}" ;;
        --host=*)    host="${arg#*=}" ;;
        --message=*) v="${arg#*=}" ;;
        --command=*) command="${arg#*=}" ;;
    esac
done

VOTE_LOCK="$PLUGIN_TEMP/${reply//\//|}-vote"
YES="$VOTE_LOCK/yes"
NO="$VOTE_LOCK/no"
ISSUE="$VOTE_LOCK/issue"
DURATION="120"
BOLD=$'\002'
COLOR=$'\003'

# $1 - user's host
already_vote_check() {
    grep -q -F -- "$1" "$YES" "$NO" && {
        printf '%s\n' ":mn $nick You have already voted."
        exit 0
    }
}

# $1 - channel name
standings() {
    yes="$(wc -l < "$YES")"
    no="$(wc -l  < "$NO")"
    printf '%s\n' ":r Yes ${COLOR}03${yes:-0}" \
                  ":r No  ${COLOR}04${no:-0}"
}

# parse args
while [[ -n "$v" ]]; do
    key="${v%% *}"

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
                ":r usage: $command [--duration=#] <y/n question>" \
                ":r create a vote for a given question." \
                ":r duration option must be between 30 to 3600 seconds."
            exit 0
        ;;
        '') ;;
        *)
            [ -z "$LAST" ] && break
            LAST=
            if [[ "$key" =~ ^[0-9]*$ ]]; then
                (( key > 30 && key < 3601 )) &&
                    DURATION="$key"
            fi
        ;;
    esac

    if [[ "${v#"$key" }" == "$v" ]]; then
        v=
    else
        v="${v#"$key" }"
    fi
done

if [[ ! -d "$VOTE_LOCK" && "$command" != 'vote' ]]; then
    printf '%s\n' ":r No vote in progress; please use .vote question"
    exit 0
fi

case "$command" in
    standings)
        printf '%s\n' \
            ":r ${BOLD}Current Standings${BOLD} $(< "$ISSUE")"
        standings
        exit 0
    ;;
    vote)
        if ! mkdir "$VOTE_LOCK" 2>/dev/null; then
            echo ':r A vote is already in progress.'
            exit 0
        fi
        printf '%s\n' "$v" > "$ISSUE"

        printf '%s %s\n' \
            ":r A vote on the issue ( ${v:0:200} ) has started and" \
            "will finish in $DURATION seconds."
        printf '%s %s\n' \
            ":r Use ${BOLD}.yes${BOLD} or ${BOLD}.no${BOLD} to vote;" \
            "${BOLD}.standings${BOLD} to view current results."

        sleep "${DURATION}s"
        printf '%s\n' ":r ${BOLD}Vote results${BOLD} $v"
        standings
        rm -rf -- "$VOTE_LOCK"
    ;;
    yes)
        already_vote_check "$host"
        printf '%s\n' "$host" >> "$YES"
        printf '%s\n' ":mn $nick Your ${BOLD}yes${BOLD} vote was cast."
    ;;
    no)
        already_vote_check "$host"
        printf '%s\n' "$host" >> "$NO"
        printf '%s\n' ":mn $nick Your ${BOLD}no${BOLD} vote was cast."
    ;;
esac
