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

# Create king james and quran sqlite3 db, for full text searching

qtemp='.qinserts.sql'
btemp='.kjinserts.sql'

echo '--- creating insert statements ---'
while IFS='|' read -r book verse; do
    echo "INSERT INTO king_james VALUES ('$book', '${verse//\'/\'\'}');"
done < 'king-james.txt' > "$btemp"

while IFS='|' read -r vid verse; do
    echo "INSERT INTO quran VALUES ('$vid', '${verse//\'/\'\'}');"
done < 'quran-allah-ver.txt' > "$qtemp"

echo '--- creating db ---'
sqlite3 'kjbible-quran.db' << EOF
CREATE VIRTUAL TABLE king_james USING fts5(book, verse, tokenize = 'porter unicode61');
CREATE VIRTUAL TABLE quran USING fts5(vid, verse, tokenize = 'porter unicode61');
EOF

echo '--- inserting bible verses ---'
sqlite3 'kjbible-quran.db' < "$btemp"
echo '--- inserting quran verses ---'
sqlite3 'kjbible-quran.db' < "$qtemp"
echo '--- deleting temp inserts ---'
rm "$qtemp" "$btemp"
