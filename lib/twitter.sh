#!/bin/bash
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

TWITTER_OAUTH_URL='https://api.twitter.com/oauth2/token'
TWITTER_TIMELINE_URL='https://api.twitter.com/1.1/statuses/user_timeline.json?count=1&screen_name='
channel="$1"

msg="$4"
for arg in $4; do
    case "$arg" in
        -f|--follow)
            echo ":m $1 currently not implemented."
            exit
        ;;
        -u|--unfollow)
            echo ":m $1 currently not implemented."
            exit
        ;;
        -h|--help)
            echo ":m $1 usage: $5 [--(un)follow] [@]screen_name"
            echo ":m $1 Get latest tweets from a user"
            exit 0
        ;;
        *)
            screen_name="$msg"
            break
        ;;
    esac

done

# generate a bearer token.
# Note: if the token isn't valid, the plugin closes
# mutates - $bearer_token
generate_bearer_token() {
    if ! bearer_token="$(curl --compressed -s "$TWITTER_OAUTH_URL" \
        -u "$TWITTER_KEY:$TWITTER_SECRET" \
        -H 'User-Agent: neo8ball' \
        --data-urlencode 'grant_type=client_credentials')"
    then
        echo ":m $channel Could not get a Twitter OAUTH bearer token"
        exit
    fi
    bearer_token="$(jq -r .access_token <<< "$bearer_token" 2>/dev/null)"
    if [[ -z "$bearer_token" ]]; then
        echo ":m $channel Could not get a Twitter OAUTH bearer token"
        exit
    fi
}

# get a username's latest tweet
# $1 - screen name
# mutates - REPLY
get_latest_tweet() {
    [ -z "$bearer_token" ] && generate_bearer_token
    if ! res="$(curl -s --compressed "$TWITTER_TIMELINE_URL${1#@}" \
        -H "Authorization: Bearer $bearer_token" \
        -H 'User-Agent: neo8ball')"
    then
        return 1
    fi

    REPLY=$'\002'"$1"$'\002'" - $(jq -r '.[0] | 
        .created_at + ": " + 
        (.text|gsub("\n"; " "))
    ' <<< "$res" | recode html..utf8)"
}

if get_latest_tweet "$screen_name"; then
    echo ":m $1 ${REPLY:0:300}"
else
    echo ":m $1 $screen_name - no such user."
fi
