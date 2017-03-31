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

youtube="https://www.googleapis.com/youtube/v3/search?part=snippet&type=video&q=$(URI_ENCODE "$4")&maxResults=3&key=${YOUTUBE_KEY}"


while read -r id title; do
    [ -z "$title" ] && exit
    stats="https://www.googleapis.com/youtube/v3/videos?part=statistics&id=${id}&key=${YOUTUBE_KEY}"
    echo stats
    while read -r likes dislikes views; do
        echo -e ":m $1 "$'\002'"${title}\002 "$'\003'"03::\003 https://youtu.be/${id} "$'\003'"03::\003" \
                      $'\003'"09\u25B2 $(numfmt --grouping "$likes")\003 "$'\003'"03::\003" \
                      $'\003'"04\u25BC $(numfmt --grouping "$dislikes")\003 "$'\003'"03::\003" \
                      "\002Views\002 $(numfmt --grouping "$views")"
	done < <(
	    curl "${stats}" -f 2>/dev/null |
	    jq -r '.items[0] //empty |
		.statistics.likeCount + " " + 
		.statistics.dislikeCount + " " +
		.statistics.viewCount
   	    '
	)
done < <(
    curl "${youtube}" -f 2>/dev/null |
    jq -r '.items[0],.items[1],.items[2] //empty |
        .id.videoId + " " + 
        .snippet.title                
    '
)
