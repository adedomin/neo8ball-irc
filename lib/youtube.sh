#!/usr/bin/env bash
# Copyright 2017 prussian <genunrest@gmail.com>
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

youtube="https://www.googleapis.com/youtube/v3/search?part=snippet&type=video&q=$(URI_ENCODE "$3")&maxResults=3&key=${key}"


while read -r id title; do
    [ -z "$title" ] && exit
    stats="https://www.googleapis.com/youtube/v3/videos?part=statistics&id="${id}"&key=${key}"
    echo -e ":m Stats URL: ${stats}"
    while read -r likes dislikes views; do
	commalikes=$( echo $likes | sed 's/\B[0-9]\{3\}\>/,&/' )
	commadislikes=$( echo $dislikes | sed 's/\B[0-9]\{3\}\>/,&/' )
	commaviews=$( echo $views | sed 's/\B[0-9]\{3\}\>/,&/' )
    	echo -e ":m $1 \002${title}\002 :: https://youtu.be/${id} :: \u25B2 ${commalikes} | \u25BC ${commadislikes} | VIEWS: ${commaviews}"
	done < <(
	    curl "${stats}" -f 2>/dev/null |
	    jq -r '.items[0],.items[1] //empty |
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
