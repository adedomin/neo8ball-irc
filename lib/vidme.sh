#!/usr/bin/env bash
URI='https://vid.me/api/videos/search?order=hot&query='
RES=$(curl "${URI}$(sed 's/ /+/g' <<< "$4")" 2>/dev/null | \
    jq -r '.videos[0],.videos[1],.videos[2] | .full_url + " :: " + .title'
)

IFS=$'\n'
for res in $RES; do
    if [ "$res" = ' :: ' ]; then
        echo ":m $1 no results found"
        exit 0
    fi
    echo ":m $1 $res"
done
