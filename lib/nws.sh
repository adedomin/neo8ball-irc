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

arg="$4"
if [ -z "$arg" ] && \
    [ -n "$WEATHER_DB" ]; then

    if [ ! -f "$WEATHER_DB" ]; then
        echo ":mn $3 You have to set a default location first, use .nwsd <station> or .nwsl <station>"

        echo ":mn $3 See http://w1.weather.gov/xml/current_obs/seek.php to find a station"
        exit 0
    fi

    IFS=$':' read -r USR arg < <( grep "^NWS~$3:" "$WEATHER_DB" )
    if [ -z "$arg" ]; then
        echo ":mn $3 You have to set a default location first, use .nwsd <station> or .nwsl <station>"
        echo ":mn $3 See http://w1.weather.gov/xml/current_obs/seek.php to find a station"
        exit 0
    fi
fi

if [ "$arg" = 'help' ]; then
    echo ":m $1 See http://w1.weather.gov/xml/current_obs/seek.php to find a station"
    exit 0
fi

NWS="http://w1.weather.gov/xml/current_obs/${arg^^}.xml"



IFS=$'='
while read -r key value; do
    case $key in
        *location)
            LOC="$value"
        ;;
        *temperature_string)
            TEMP="$value"
        ;;
        *temp_f)
            T_F="$value"
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
done < <( 
    curl "$NWS" -f 2>/dev/null | \
    xml2 2>/dev/null
)

if [ -z "$LOC" ]; then
    echo ":m $1 Invalid station"
    echo ":mn $3 See http://w1.weather.gov/xml/current_obs/seek.php to find a station"
    exit 0
fi

# add color to temps!!!
if [ "$(bc -l <<< "$T_F >= 80.00")" -eq 1 ]; then
    TEMP_COL=$'\003'"04"
elif [ "$(bc -l <<< "$T_F < 45.00")" -eq 1 ]; then
    TEMP_COL=$'\003'"02"
else
    TEMP_COL=$'\003'"03"
fi

echo -e ":m $1 \002${LOC}\002 :: \002Conditions\002 ${CONDITIONS} :: \002Temp\002 ${TEMP_COL}${TEMP}\003 :: \002Wind\002 $WIND :: \002Humidity\002 ${HUMIDITY}%"
