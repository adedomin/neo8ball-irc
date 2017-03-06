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

if [ "$5" = 'quran' ]; then
    table='quran'
else
    table='king_james'
fi

if [ -z "$BIBLE_SOURCE" ] || [ ! -f "$BIBLE_SOURCE" ]; then
    echo ":m $1 No bible or quran available." 
    exit 0
fi

if [ -z "$4" ]; then
    printf ":m $1 %s\n" "$(sqlite3 "$BIBLE_SOURCE" <<< "SELECT * FROM $table ORDER BY RANDOM() LIMIT 1;")"
    exit 0
fi

q="${4//\'/\'\'}"
q="$(sed 's/[.:]/"&"/g' <<< "$q")"

printf ":m $1 %s\n" "$(sqlite3 "$BIBLE_SOURCE" << EOF
SELECT * FROM $table 
  WHERE $table 
  MATCH '$q' 
  ORDER BY rank 
  LIMIT 1;
EOF
)"
