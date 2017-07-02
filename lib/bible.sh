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

declare -i COUNT
COUNT=1

# parse args
while IFS='=' read -r key val; do
    case "$key" in
        # TODO: revisit
        #-c|--count)
        #    [[ "$val" =~ ^[1-3]$ ]] &&
        #        COUNT="$val"
        #;;
        -h|--help)
            echo ":m $1 usage: $5 [query]"
            echo ":m $1 find or get random verse from either the kjv bible or the quran."
            exit 0
        ;;
    esac
done <<< "$6"

if [ "$5" = 'quran' ]; then
    table='quran'
    BIBLE_SOURCE="$QURAN_SOURCE"
else
    table='king_james'
fi

if [ -n "$BIBLE_DB" ] && [ -f "$BIBLE_DB" ]; then

    if [ -z "$4" ]; then
        printf ":m $1 %s\n" "$(sqlite3 "$BIBLE_DB" <<< "SELECT * FROM $table ORDER BY RANDOM() LIMIT $COUNT;")"
        exit 0
    fi

    q="${4//\'/\'\'}"
    if [[ "$q" =~ [-.:\{\}] ]]; then
        q="\"$q\""
    fi

    verse="$(sqlite3 "$BIBLE_DB" << EOF
SELECT * FROM $table 
WHERE $table 
MATCH '$q' 
ORDER BY rank 
LIMIT $COUNT;
EOF
    )"
    
    echo ":m $1 ${verse:-Nothing Found}"

elif [ -n "$BIBLE_SOURCE" ] && [ -f "$BIBLE_SOURCE" ]; then
    
    if [ -z "$4" ]; then
        printf ":m $1 %s" "$(shuf -n"$COUNT" "$BIBLE_SOURCE")"
        exit 0
    fi

    verse="$(grep -F -m "$COUNT" "$4" "$BIBLE_SOURCE")"
    echo ":m $1 ${verse:-Nothing Found}"

else

    echo ":m $1 No bible available"

fi
