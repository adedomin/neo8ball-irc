#!/usr/bin/env bash
# Copyright 2017 prussian <genunrest@gmail.com>, underdoge <eduardo.chapa@gmail.com>
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

if [ -z "$4" ]; then
    echo ":mn $3 This command requires a search query"
    exit 0
fi

if [ "$5" = 'youtu.be' ] || [ "$5" = 'youtube.com' ]; then
    ids="$(grep -Po '(?<=watch\?v=)[^&?\s]*|(?<=youtu\.be/)[^?&\s]*' <<< "$4")"
fi

if [ -z "$ids" ]; then
    youtube="https://www.googleapis.com/youtube/v3/search?part=snippet&type=video&q=$(URI_ENCODE "$4")&maxResults=3&key=${YOUTUBE_KEY}"
    while read -r id; do
        if [ -z "$ids" ]; then
            ids=$id
        else
            ids=$ids,$id
        fi

    done < <(
        curl "${youtube}" -f 2>/dev/null |
        jq -r '.items[0],.items[1],.items[2] //empty |
               .id.videoId'
    )
fi

stats="https://www.googleapis.com/youtube/v3/videos?part=snippet,statistics&id=${ids}&key=${YOUTUBE_KEY}"

while read -r id2 likes dislikes views title; do
    [ -z "$title" ] && exit 0
    echo -e ":m $1 "$'\002'"${title}\002 "$'\003'"09::\003 https://youtu.be/${id2} "$'\003'"09::\003" \
                    $'\003'"03\u25B2 $(numfmt --grouping "$likes")\003 "$'\003'"09::\003" \
                    $'\003'"04\u25BC $(numfmt --grouping "$dislikes")\003 "$'\003'"09::\003" \
                    "\002Views\002 $(numfmt --grouping "$views")"
done < <(
    curl "${stats}" 2>/dev/null |
    jq -r '.items[0],.items[1],.items[2] //empty |
        .id + " " +
        .statistics.likeCount + " " +
        .statistics.dislikeCount + " " +
        .statistics.viewCount + " " +
        .snippet.title'
)
