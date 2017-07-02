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

# parse args
while IFS='=' read -r key val; do
    case "$key" in
        -s|--search)
            SEARCH=1
        ;;
        -S|--save)
            SAVE=1
            [ -n "$val" ] &&
                arg="$val"
        ;;
        -h|--help)
            echo ":m $1 usage: $5 [--search|--save=station] [query]"
            echo ":m $1 plugin that uses the NWS METAR XML api to get current weather observations."
            echo ":m $1 note that a query must be an airport or other METAR station, e.g. KLAX."
            exit 0
        ;;
    esac
done <<< "$6"

if [ -z "$arg" ]; then
    arg=$(GET_LOC "NWS~$3")
    if [ -z "$arg" ]; then
        echo ":mn $3 you must set a default location first"
        echo ":mn $3 use --save=STATION"
        exit 0
    fi
fi

if [ -n "$SEARCH" ]; then
    if [ -z "$PERSIST_LOC" ]; then
        echo ":mn $3 search is disabled"
        exit 0
    fi

    if [ ! -f "$PERSIST_LOC/stations.txt" ]; then
        curl 'http://weather.rap.ucar.edu/surface/stations.txt' \
            -L 2>/dev/null \
        | sed '/^!/d' > "$PERSIST_LOC/stations.txt"
    fi

    # shellcheck disable=2034
    query="$arg"
    while read -r line; do
        echo ":m $1 $line"
    done < <(
        grep -F -m 3 -i "$query" "$PERSIST_LOC/stations.txt" \
        | cut -c 4-24
    )
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
    echo ":m $1 invalid station"
    echo ":m $1 find a station: .$5 --search <city or airport>"
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

if [ -n "$W_TEMP" ]; then
    if [ "$(bc -l <<< "$WT_F >= 80.00")" -eq 1 ]; then
        WTEMP_COL=$'\003'"04"
    elif [ "$(bc -l <<< "$WT_F < 45.00")" -eq 1 ]; then
        WTEMP_COL=$'\003'"02"
    else
        WTEMP_COL=$'\003'"03"
    fi
else
    WTEMP_COL="$TEMP_COL"
    W_TEMP="N/A"
fi

echo -e ":m $1 \002${LOC}\002 :: ${CONDITIONS} ::" \
    "\002Temp\002 ${TEMP_COL}${TEMP}\003 ::" \
    "\002Windchill\002 ${WTEMP_COL}${W_TEMP}\003 ::" \
    "\002Wind\002 $WIND ::" \
    "\002Humidity\002 ${HUMIDITY}% ::" \
    "\002Dewpoint\002 ${DEW} ::" \
    "\002Pressure\002 ${PRESSURE}"

# valid station... so save it
if [ -n "$SAVE" ]; then
    if ! SAVE_LOC "NWS~$3" "$arg"; then
        echo ":mn $3 there was a problem saving your defaults"
        echo ":logw NWS -> failed to save $arg for $3"
    fi
fi
