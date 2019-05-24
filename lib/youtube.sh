#!/usr/bin/env bash
# Copyright 2017 Anthony DeDominic <adedomin@gmail.com>, underdoge <eduardo.chapa@gmail.com>
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

MATCH="$4"
# parse args
for key in $4; do
    case "$key" in
        -c|--count)
            LAST='c'
        ;;
        --count=*)
            [[ "${key#*=}" =~ ^[1-3]$ ]] &&
                COUNT="${key#*=}"
        ;;
        -h|--help)
            echo ":m $1 usage: $5 [--count=#-to-ret] query"
            echo ":m $1 search for a youtube video."
            exit 0
        ;;
        *)
            [[ -z "$LAST" ]] && break
            LAST=
            [[ "$key" =~ ^[1-3]$ ]] &&
                COUNT="$key"
        ;;
    esac
    if [[ "$MATCH" == "${MATCH#* }" ]]; then
        MATCH=
        break
    else
        MATCH="${MATCH#* }"
    fi
done

if [[ -z "$MATCH" ]]; then
    echo ":mn $3 This command requires a search query"
    exit 0
fi

if [[ -z "$YOUTUBE_KEY" ]]; then
    echo ":mn $3 this command is disabled; no api key"
    exit 0
fi

if [[ -n "$6" ]]; then
    CHANNEL_IN_IGNORE_LIST "$1" "$YOUTUBE_IGNORE" &&
        exit 0
    COUNT=1

    if ! ids="$(
        awk -v qstr="$MATCH" -- 'BEGIN {
            len = split(qstr, q)
            for (i=1; i<=len; ++i) {
                if (ind = index(q[i], "youtu.be/")) {
                    print substr(q[i], ind + 9)
                    exit 0
                }
                if (ind = index(q[i], "youtube.com/watch?")) {
                    form = substr(q[i], ind + 19)
                    pos = index(form, "v=")
                    print substr(form, pos + 2)
                    exit 0
                }
            }
            exit 1
        }'
    )"; then
        exit 0
    fi
else
    youtube="https://www.googleapis.com/youtube/v3/search?part=snippet&type=video&q=$(URI_ENCODE "$MATCH")&maxResults=${COUNT}&key=${YOUTUBE_KEY}"
    ids="$(
        {
            curl --silent --fail "${youtube}" ||
                echo null
        } | jq -r '
            if (.items) then
                [ .items[0:3][] | .id.videoId ]
                | join(",")
            else
                empty
            end
        '
    )"
fi

[[ -z "$ids" ]] && exit 0

stats="https://www.googleapis.com/youtube/v3/videos?part=snippet,statistics,contentDetails&id=${ids}&key=${YOUTUBE_KEY}"

{
    curl --silent --fail "${stats}" ||
        echo null
} | jq --arg CHANNEL "$1" \
    -r 'def rev_string:
            explode
            | reverse
            | implode
        ;
        def group_digits:
            def _group:
                if (. | length) > 3 then
                    .[0:3] + "," + (.[3:] | _group)
                else
                    .
                end
            ;
            . | tostring
            | rev_string
            | _group
            | rev_string
        ;
        if (.items) then
            .items[0:3][]
            | ":m \($CHANNEL) \u0002" + .snippet.title + "\u0002 (" + (
                .contentDetails.duration[2:] | ascii_downcase
            ) + ") :: " +
            "https://youtu.be/" + .id + " :: " +
            "\u0003" + "03" + "\u25b2 " + (
                .statistics.likeCount | group_digits
            ) + "\u0003" + " :: " +
            "\u0003" + "04" + "\u25bc " + (
                .statistics.dislikeCount | group_digits
            ) + "\u0003" + " :: " +
            "\u0002Views\u0002 " + (
                .statistics.viewCount | group_digits
            ) + " :: " +
            "\u0002by\u0002 " + .snippet.channelTitle +
            " \u0002on\u0002 " + .snippet.publishedAt[0:10]
        else
            empty
        end
'
