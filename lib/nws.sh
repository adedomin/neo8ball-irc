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
    echo ":mn $3 See http://w1.weather.gov/xml/current_obs/seek.php to find a station"
    exit 0
fi

if [ "$4" = 'help' ]; then
    echo ":m $1 See http://w1.weather.gov/xml/current_obs/seek.php to find a station"
    exit 0
fi

NWS="http://w1.weather.gov/xml/current_obs/${4^^}.xml"

RES="$(curl "$NWS" -f 2>/dev/null | \
    xml2 2>/dev/null 
)"

if [ -z "$RES" ]; then
    echo ":m $1 Invalid station"
    echo ":mn $3 See http://w1.weather.gov/xml/current_obs/seek.php to find a station"
    exit 0
fi

IFS=$'='
while read -r key value; do
    case $key in
        *location)
            LOC="$value"
        ;;
        *temperature_string)
            TEMP="$value"
        ;;
        *wind_string)
            WIND="$value"
        ;;
        *weather)
            CONDITIONS="$value"
        ;;
        *humidity)
            HUMIDITY="$value"
        ;;

    esac
done <<< "$RES"

echo -e ":m $1 \002${LOC}\002 :: \002Conditions\002 ${CONDITIONS} :: \002Temp\002 $TEMP :: \002Wind\002 $WIND :: \002Humidity\002 ${HUMIDITY}%"
