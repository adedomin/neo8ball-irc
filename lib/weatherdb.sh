#!/usr/bin/env bash

if [ -z "$WEATHER_DB" ] ||\
    [ ! -f "$WEATHER_DB" ]; then

    echo ":mn $3 This feature is not enabled"
    exit 0
fi

# must buffer to ensure the file is saved properly
echo "$( jq -c '. | .["'"$3"'"] = "'"$4"'"' < "$WEATHER_DB" )" \
    > "$WEATHER_DB"
echo ":mn $3 You can now use .w without any arguments"
