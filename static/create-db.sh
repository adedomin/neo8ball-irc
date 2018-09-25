#!/bin/sh
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

printf '%s\n' '--- creating db: kjbible-quran.db ---'
rm -f -- kjbible-quran.db
awk -F'|' -- '
    BEGIN {
        print "CREATE VIRTUAL TABLE king_james USING fts5("
        print "  book, verse, tokenize = \047porter unicode61\047"
        print ");"
        print "CREATE VIRTUAL TABLE quran USING fts5("
        print "  vid, verse, tokenize = \047porter unicode61\047"
        print ");"
        print "BEGIN TRANSACTION;"
    }
    function esc(str) {
        gsub(/\047/, "\047\047", str)
        return "\047" str "\047"
    }
    {
        if (FILENAME == "king-james.txt") table = "king_james"
        else table = "quran"
        print "INSERT INTO " table " VALUES (" esc($1) ", " esc($2) ");"
    }
    END { print "COMMIT TRANSACTION;" }
' king-james.txt quran-allah-ver.txt | sqlite3 kjbible-quran.db
