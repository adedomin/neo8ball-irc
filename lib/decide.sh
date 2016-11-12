#!/usr/bin/env bash
reg="(.*) or (.*)\?" # decide
reg2="(.*)\?" # regular 8ball msg
if [[ "$4" =~ $reg ]]; then
    echo ":m $1 $3: ${BASH_REMATCH[($RANDOM % 2)+1]}"
else if [[ "$4" =~ $reg2 ]]; then
    ./lib/8ball.sh "$1" "$2" "$3" "$4"
fi
