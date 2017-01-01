#!/usr/bin/env bash
URI='https://vid.me/api/videos/search?query='
RES=$(curl "${URI}${4}" 2>/dev/null | \
    jq -r '.videos[0],.videos[1],.videos[2] | .full_url + " :: " + .title'
)

IFS=$'\n'
for res in $RES; do
    echo ":m $1 $res"
done
