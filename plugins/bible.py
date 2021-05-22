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

from typing import TextIO, Union
from pathlib import Path
from io import StringIO

from py8ball import main_decorator
from py8ball.sqlite3_helpers import Sqlite3Manager, escape_fts5
from py8ball.logging import log_e
from py8ball.environment import get_persistant_location
from py8ball.http_helpers import paste_service


try:
    BIBLE_DB_PATH = get_persistant_location() / 'bible-plugin.db'
    BIBLE_DB = Sqlite3Manager(BIBLE_DB_PATH)
except KeyError:
    log_e('$PERSIST_LOC or $XDG_DATA_HOME are not defined.')
    exit(1)


def read_bible_txt(cursor: sqlite3.Cursor,
                   the_good_book: str,
                   f: TextIO):
    """Populate the database with text from a bible."""
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


def populate_db(cursor: sqlite3.Cursor):
    """Load the king james bible text into the db."""
    statics = Path(__file__).parent / '..' / 'static'
    kjb = statics / 'king-james.txt'
    with kjb.open('r') as f:
        read_bible_txt(cursor, 'king_james', f)
    # quran = statics / 'quran-allah-ver.txt'
    # with quran.open('r') as f:
    #     read_bible_txt(cursor, 'quran', f)


# sqlite3 already comes with a full-text search engine ootb.
@BIBLE_DB.apply
def setup_db(*, db: sqlite3.Connection):
    """Ensure the sqlite3 schema exists, populate the db."""
    cur = db.cursor()
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
    stmt = cur.execute("SELECT bid FROM king_james LIMIT 1")
    row = stmt.fetchone()
    if row is None:
        populate_db(cur)


@BIBLE_DB.apply
def find_by_book(book: str, count: int = -1, *,
                 db: sqlite3.Connection) -> list[str]:
    """Find by book + verse pair."""
    cur = db.cursor()
    stmt = cur.execute("""
    SELECT bid, book, verse
    FROM king_james
    WHERE book = ?
    """, (book,))
    result_set = []
    bid_to = -1

    row = stmt.fetchone()
    if row is not None:
        bid, bookv, verse = row
        result_set.append(f'{bookv} | {verse}')
        bid_to = bid + count
    else:
        return [f'No such verse: {book}']

    if bid_to != -1 and count != -1:
        stmt = cur.execute("""
        SELECT book, verse
        FROM king_james
        WHERE bid > ? AND bid < ?
        """, (bid, bid_to))
        for bookv, verse in stmt:
            result_set.append(f'{bookv} | {verse}')

    return result_set


@BIBLE_DB.apply
def random_verse(*, db: sqlite3.Connection) -> str:
    """Fetch a random book + verse."""
    cur = db.cursor()
    stmt = cur.execute("""
    SELECT book, verse FROM king_james
    WHERE bid = (
        (ABS(RANDOM())) % (SELECT max(bid) FROM king_james) + 1
    )
    """)
    row = stmt.fetchone()
    if row is not None:
        book, verse = row
        return f'{book} | {verse}'
    else:
        return 'Random query error.'


@BIBLE_DB.apply
def find_verse(query: str, *, db) -> str:
    """Find a book + verse from a given query."""
    cur = db.cursor()
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
    row = stmt.fetchone()
    if row is not None:
        book, verse = row
        return f'{book} | {verse}'
    else:
        return f'No such verse containing: {query[0:15]}...'


def parse_query(query: str) -> (Union[str, None], int):
    """Parse a user provided query."""
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


@main_decorator
def main(*,
         message: str = '') -> int:
    """Entrypoint."""
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

    if message == '':
        print(f':r {random_verse()}')
    else:
        query, count = parse_query(message)
        if query is None:
            print(f':r {find_verse(message)}')
        elif count > 9:
            print(':r Verse counts greater than 9 are currently unsupported.')
        elif count < 1:
            print(':r Verse counts must be greater than 0.')
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
