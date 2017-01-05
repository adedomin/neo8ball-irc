#!/usr/bin/env bash

if [ -z "$WEATHER_DB" ] ||\
    [ ! -f "$WEATHER_DB" ]; then

    echo ":mn $3 This feature is not enabled"
    exit 0
fi

if [ -z "$4" ]; then
    echo "$( jq -c 'del(.["'"$3"'"])' \
        < "$WEATHER_DB" )" \
        > "$WEATHER_DB"
    echo ":mn $3 Your default was deleted"
else
    echo "$( jq -c '. | .["'"$3"'"] = "'"$4"'"' \
        < "$WEATHER_DB" )" \
        > "$WEATHER_DB"
    echo ":mn $3 You can now use the weather command without arguments"
fi
