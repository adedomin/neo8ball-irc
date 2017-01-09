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

# format -> username:their weather location

if [ -z "$PERSIST_LOC" ]; then
    echo ":mn $3 This feature is not enabled"
    exit 0
fi

WEATHER_DB="$PERSIST_LOC/weather-defaults.db"

if [ ! -f "$WEATHER_DB" ]; then
    touch "$WEATHER_DB"
fi

USER="$3"
if [ "$5" = 'nwsl' ] || [ "$5" = 'nwsd' ]; then
    USER="NWS~$3"
fi

if [ -z "$4" ]; then
    sed -i'' '/^'"$USER"':/d' "$WEATHER_DB"
    echo ":mn $USER Your defaults were deleted"
elif grep -q "^$USER:" "$WEATHER_DB"; then
    sed -i'' 's/^'"$USER"':.*$/'"$USER"':'"$4"'/' "$WEATHER_DB"
    echo ":mn $3 Your default has changed"
else
    echo "$USER:$4" >> "$WEATHER_DB"
    echo ":mn $3 You can now use the weather command without arguments"
fi
