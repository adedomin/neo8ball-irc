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

for arg; do
    case "$arg" in
        --message=*) msg="${arg#*=}" ;;
        --command=*) command="${arg#*=}" ;;
        --regexp=*)  command="${arg#*=}" ;;
        --match=*)   match="${arg#*=}" ;;
    esac
done

TWITTER_OAUTH_URL='https://api.twitter.com/oauth2/token'
TWITTER_TIMELINE_URL='https://api.twitter.com/1.1/statuses/user_timeline.json?count=1&screen_name='
TWITTER_STATUS_URL='https://api.twitter.com/1.1/statuses/show.json?id='

if [[ -z "$match" ]]; then
    while [[ -n "$msg" ]]; do
        arg="${msg%% *}"

        case "$arg" in
            -f|--follow)
                echo ":r currently not implemented."
                exit
            ;;
            -u|--unfollow)
                echo ":r currently not implemented."
                exit
            ;;
            -h|--help)
                echo ":r usage: $command [--(un)follow] [@]screen_name"
                echo ":r Get latest tweets from a user"
                exit 0
            ;;
            *)
                screen_name="$msg"
                break
            ;;
        esac
    done
elif [[ "${match##*status/}" != "$match" ]]; then
    status_id="${match##*status/}"
elif [[ "${match##*t.co/}" != "$match" ]]; then
    status_id="$(curl --head -s -q "https://$match" \
                 | grep -i -- '^location: ' \
                 | tr -d '\r\n')"
    [[ "${status_id##*status/}" == "$status_id" ]] && exit 0
    status_id="${status_id##*status/}"
else
    exit
fi

# generate a bearer token.
# Note: if the token isn't valid, the plugin closes
# mutates - $bearer_token
generate_bearer_token() {
    if ! bearer_token="$(curl --compressed -s "$TWITTER_OAUTH_URL" \
        -u "$TWITTER_KEY:$TWITTER_SECRET" \
        -H 'User-Agent: neo8ball' \
        --data-urlencode 'grant_type=client_credentials')"
    then
        echo ":r Could not get a Twitter OAUTH bearer token"
        exit
    fi
    bearer_token="$(jq -r .access_token <<< "$bearer_token" 2>/dev/null)"
    if [[ -z "$bearer_token" ]]; then
        echo ":r Could not get a Twitter OAUTH bearer token"
        exit
    fi
}

# get a username's latest tweet
# $1 - screen name
# mutates - REPLY
get_latest_tweet() {
    [[ -z "$bearer_token" ]] && generate_bearer_token
    if ! res="$(curl -s --compressed "$TWITTER_TIMELINE_URL${1#@}" \
                     -H "Authorization: Bearer $bearer_token")"
    then
        printf '%s\n' "$res"
        return 1
    fi

    printf '%s' $'\002'"$1"$'\002'" - "
    jq -r '.[0] |
        .created_at + ": " +
        (.full_text|gsub("\n"; " "))
    ' <<< "$res" \
    | HTML_CHAR_ENT_TO_UTF8
}

get_tweet_status() {
    [[ -z "$bearer_token" ]] && generate_bearer_token
    if ! res="$(curl -s --compressed "${TWITTER_STATUS_URL}${status_id}" \
                     -H "Authorization: Bearer $bearer_token")"
    then
        printf '%s\n' "$res"
        return 1
    fi

    printf '%s' $'\002'Tweet$'\002'" - "
    jq -r '"By \(.user.screen_name) At \(.created_at): " + 
           (.full_text|gsub("\n"; ""))
    ' <<< "$res" | HTML_CHAR_ENT_TO_UTF8
}

if [[ -n "$status_id" ]]; then
    if TWEET="$(get_tweet_status)"; then
        printf ':r %s\n' "${TWEET:0:400}"
    else
        echo ":loge $0 $TWEET"
    fi
elif TWEET="$(get_latest_tweet "$screen_name")"; then
    echo ":r ${TWEET:0:400}"
else
    echo ":r $screen_name - no such user."
fi
