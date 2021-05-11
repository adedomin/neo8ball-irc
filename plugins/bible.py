#!/usr/bin/env python3
# Copyright (C) 2021  Anthony DeDominic <adedomin@gmail.com>

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import sqlite3
import re

from pathlib import Path
from io import StringIO
from py8ball import get_args, Flag, \
    get_persistant_location, \
    paste_service, log_e, escape_fts5


try:
    BIBLE_DB = get_persistant_location() / 'bible-plugin.db'
except KeyError:
    log_e('$PERSIST_LOC or $XDG_DATA_HOME are not defined.')
    exit(1)


def read_bible_txt(cursor, the_good_book, f):
    lineno = 1
    for line in f:
        book, verse = line.split('|', maxsplit=1)
        book = book.strip()
        verse = verse.strip()
        cursor.execute(f'INSERT INTO {the_good_book}'
                       '(bid, book, verse) VALUES (?, ?, ?)',
                       (lineno, book, verse))
        cursor.execute(f'INSERT INTO {the_good_book+"_verse"}'
                       '(vid, verse_text) VALUES (?, ?)',
                       (lineno, verse,))
        lineno += 1


def populate_db(cursor):
    statics = Path(__file__).parent / '..' / 'static'
    kjb = statics / 'king-james.txt'
    with kjb.open('r') as f:
        read_bible_txt(cursor, 'king_james', f)
    # quran = statics / 'quran-allah-ver.txt'
    # with quran.open('r') as f:
    #     read_bible_txt(cursor, 'quran', f)


# sqlite3 already comes with a full-text search engine ootb.
def setup_db():
    conn = sqlite3.connect(BIBLE_DB)
    with conn:
        cur = conn.cursor()
        cur.execute("""
        CREATE TABLE IF NOT EXISTS king_james (
            bid INTEGER PRIMARY KEY NOT NULL,
            book TEXT NOT NULL,
            verse TEXT NOT NULL
        ) WITHOUT ROWID;
        """)
        cur.execute("""
        CREATE INDEX IF NOT EXISTS king_jamesIdxBook
        ON king_james (book);
        """)
        cur.execute("""
        CREATE VIRTUAL TABLE IF NOT EXISTS king_james_verse USING fts5(
            vid, verse_text, tokenize = 'porter'
        )
        """)
        # populate if the table is empty
        for _ in cur.execute("SELECT bid FROM king_james LIMIT 1"):
            break  # skips over else clause
        else:
            populate_db(cur)
    conn.close()


def find_by_book(book: str, count: int = -1):
    conn = sqlite3.connect(BIBLE_DB)
    with conn:
        cur = conn.cursor()
        stmt = cur.execute("""
        SELECT bid, book, verse
        FROM king_james
        WHERE book = ?
        """, (book,))
        result_set = []
        bid_to = -1
        for bid, bookv, verse in stmt:
            result_set.append(f'{bookv} | {verse}')
            bid_to = bid + count
            break
        else:
            result_set.append(f'No such verse: {book}')

        if bid_to != -1 and count != -1:
            stmt = cur.execute("""
            SELECT book, verse
            FROM king_james
            WHERE bid > ? AND bid < ?
            """, (bid, bid_to))
            for bookv, verse in stmt:
                result_set.append(f'{bookv} | {verse}')
    conn.close()
    return result_set


def random_verse():
    conn = sqlite3.connect(BIBLE_DB)
    with conn:
        cur = conn.cursor()
        stmt = cur.execute("""
        SELECT book, verse FROM king_james
        WHERE bid = (
            (ABS(RANDOM())) % (SELECT max(bid) FROM king_james) + 1
        )
        """)
        ret = 'Random query error.'
        for book, verse in stmt:
            ret = f'{book} | {verse}'
            break
    conn.close()
    return ret


def find_verse(query):
    conn = sqlite3.connect(BIBLE_DB)
    with conn:
        cur = conn.cursor()
        stmt = cur.execute("""
        SELECT book, verse FROM king_james
        INNER JOIN (
          SELECT vid FROM king_james_verse
          WHERE king_james_verse MATCH ?
          ORDER BY RANK
          LIMIT 1
        )
        ON bid = vid
        """, (escape_fts5(query),))
        ret = 'No such verse.'
        for book, verse in stmt:
            ret = f'{book} | {verse}'
            break
    conn.close()
    return ret


def parse_query(query):
    like_book_verse = re.compile(r'\d{1,3}:\d{1,3}(?:-\d)?')
    parts = query.split(' ')
    if like_book_verse.fullmatch(parts[-1]):
        bvc = parts[-1].split('-', maxsplit=1)
        if len(bvc) == 2:
            parts[-1] = bvc[0]
            q = ' '.join(parts)
            return q, int(bvc[1])
        else:
            return query, -1
    else:
        return None, -1


def main() -> int:
    try:
        args = get_args()
    except ValueError as e:
        log_e(str(e))
        return 1

    try:
        setup_db()
    except sqlite3.Error as e:
        print(':r Could not initialize bible; try again later.')
        log_e(str(e))
        return 1
    # cmd = args.get(Flag.COMMAND, 'bible')
    # if cmd == 'quran':
    #     cmd = 'quran'
    # else:
    #     cmd = 'king_james'

    message = args.get(Flag.MESSAGE, '')
    if message == '':
        print(f':r {random_verse()}')
    else:
        query, count = parse_query(message)
        if query is None:
            print(f':r {find_verse(message)}')
        elif count > 9:
            print(':r Verse counts greater than 9 are current unsupported.')
        else:
            res = find_by_book(query, count)
            if len(res) == 1:
                print(f':r {res[0]}')
            else:
                try:
                    url = paste_service(StringIO("\n".join(res)))
                    print(f':r result: {url}')
                except Exception as e:
                    print(f': {res[0]}')
                    log_e(str(e))
                    return 1
    return 0


if __name__ == '__main__':
    exit(main())
