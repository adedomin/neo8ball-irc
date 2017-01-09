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
    [ -n "$PERSIST_LOC" ]; then

    WEATHER_DB="$PERSIST_LOC/weather-defaults.db"
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

if [[ "$arg" =~ ^search ]]; then
    if [ -z "$PERSIST_LOC" ]; then
        echo ":mn $3 search is disabled"
    fi

    if [ ! -f "$PERSIST_LOC/stations.txt" ]; then
        curl 'http://weather.rap.ucar.edu/surface/stations.txt' \
        -L 2>/dev/null | \
            sed '/^!/d' > "$PERSIST_LOC/stations.txt"
    fi

    read -r srch query <<< "$arg"
    echo ":m $1 $(grep -m 1 -i "$query" "$PERSIST_LOC/stations.txt" | cut -c 4-24)"
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
        *windchill_string)
            W_TEMP="$value"
        ;;
        *temp_f)
            T_F="$value"
        ;;
        *windchill_f)
            WT_F="$value"
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
        *pressure_string)
            PRESSURE="$value"
        ;;
        *dewpoint_string)
            DEW="$value"
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

if [ "$(bc -l <<< "$WT_F >= 80.00")" -eq 1 ]; then
    WTEMP_COL=$'\003'"04"
elif [ "$(bc -l <<< "$WT_F < 45.00")" -eq 1 ]; then
    WTEMP_COL=$'\003'"02"
else
    WTEMP_COL=$'\003'"03"
fi

echo -e ":m $1 \002${LOC}\002 :: ${CONDITIONS} :: \002Temp\002 ${TEMP_COL}${TEMP}\003 :: \002Windchill\002 ${WTEMP_COL}${W_TEMP}\003 :: \002Wind\002 $WIND :: \002Humidity\002 ${HUMIDITY}% :: \002Dewpoint\002 ${DEW} :: \002Pressure\002 ${PRESSURE}"
