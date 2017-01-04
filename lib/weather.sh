#!/usr/bin/env bash
# Copyright 2016 prussian <genunrest@gmail.com>
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

URI_ENCODE() {
    curl -Gso /dev/null \
        -w '%{url_effective}' \
        --data-urlencode @- '' <<< "$1" | \
    cut -c 3-
}

WEATHER="api.openweathermap.org/data/2.5/weather?APPID=${OWM_KEY}&"
query='q='

arg="$4"
if [ -z "$arg" ] && \
    [ -n "$WEATHER_DB" ] && \
    [ -f "$WEATHER_DB" ]; then

    arg="$(jq -r ".$3" < "$WEATHER_DB")"
    if [ -z "$arg" ]; then
        echo ":mn $3 You have to set a default location first, use .location <location> or .wd <location>"
        exit 0
    fi
fi

IFS=$',' read -r city country <<< "$arg"
# US Postal code, I don't feel like figuring out what others look like.
if [[ "$city" =~ ^[0-9]{5}(-[0-9]{4})?$ ]]; then
    query='zip='
fi

country=$(xargs echo <<< "$country")
query=${query}$(URI_ENCODE "$city")
if [ -n "$country" ]; then
    query="${query},${country}"
fi

RES=$(curl "${WEATHER}${query}" 2>/dev/null)

if [ -z "$RES" ]; then
    echo ":m $1 no weather information"
    exit 0
fi

if [ "$(jq -r '.cod' <<< "$RES")" != '200' ]; then
    echo ":m $1 $(jq -r '.message' <<< "$RES")"
    exit 0
fi

KELV=$(jq -r '.main.temp' <<< "$RES")
CURR_FAHR=$(bc <<< "scale=2;$KELV * 9 / 5 - 459.67")
CURR_CELS=$(bc <<< "scale=2;$KELV - 273.15")
COND=$(jq -r '.weather[0].description' <<< "$RES")
HUMIDITY=$(jq -r '.main.humidity' <<< "$RES")
loc=$(jq -r '. | .name + ", " + .sys.country' <<< "$RES")
city_id=$(jq -r '.id' <<< "$RES")

echo ":m $1 $loc :: Conditions $COND :: Temp $CURR_CELS °C | $CURR_FAHR °F :: Humidity $HUMIDITY%"
echo ":m $1 See More for $loc at http://openweathermap.org/city/$city_id"
