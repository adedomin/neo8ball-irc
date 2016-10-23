#!/usr/bin/env bash
reg="(.*) or (.*)\?"
if [[ "$4" =~ $reg ]]; then
    echo ":m $1 $3: ${BASH_REMATCH[($RANDOM % 2)+1]}"
else
    ./lib/8ball.sh "$1" "$2" "$3" "$4"
fi
