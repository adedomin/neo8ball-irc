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
# DEPENDS: recode

if [ -z "$4" ]; then
    echo ":mn $3 This command requires a search query"
    exit 0
fi

URBAN="http://www.urbandictionary.com/define.php?term=$(URI_ENCODE "$4")"

while read -r definition; do
    (( ${#definition} > 400 )) && 
        definition="${definition:0:400}..."
    echo ":m $1 $definition"
done < <(
  curl "$URBAN" -L -f 2>/dev/null \
   | grep -A 2 -m 3 "<div class='meaning'>" \
   | sed '/^--/d;/<\/*div/d' \
   | sed 's/<[^>]*>//g' \
   | recode html..UTF-8
)

echo ":mn $3 See More: $URBAN"
