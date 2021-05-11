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

from io import StringIO
from py8ball import get_args, Flag, \
    get_persistant_location, \
    paste_service, log_e, escape_fts5


USAGE = (':r {}usage: .{} {{ '
         'add nick quotable text | '
         'get nick [num] | '
         'search nick message. }}')


try:
    QUOTE_DB = get_persistant_location() / 'quote-plugin.db'
except KeyError:
    log_e('$PERSIST_LOC or $XDG_DATA_HOME are not defined.')
    exit(1)


def setup_db():
    '''Setup the Table schema for the quotes.py plugin'''
    conn = sqlite3.connect(QUOTE_DB)
    with conn:
        cur = conn.cursor()
        cur.execute("""
        CREATE TABLE IF NOT EXISTS irc_quotes (
            qid  INTEGER NOT NULL,
            nick TEXT NOT NULL,
            mesg TEXT NOT NULL,
            PRIMARY KEY(qid, nick)
        );
        """)
        cur.execute("""
        CREATE VIRTUAL TABLE IF NOT EXISTS irc_quotes_search USING fts5(
            row, nick, mesg, tokenize = 'porter'
        );
        """)
        cur.execute("""
        CREATE TRIGGER IF NOT EXISTS irc_quotes_ins_fts5
        AFTER INSERT ON irc_quotes
        BEGIN
            INSERT INTO irc_quotes_search(row, nick, mesg)
            VALUES (NEW.rowid, NEW.nick, NEW.mesg);
        END;
        """)
        cur.execute("""
        CREATE TRIGGER IF NOT EXISTS irc_quotes_del_fts5
        AFTER DELETE ON irc_quotes
        BEGIN
            DELETE FROM irc_quotes_search WHERE row = OLD.rowid;
        END;
        """)
    conn.close()


def get_max_qid(cur: sqlite3.Cursor, nick: str) -> int:
    stmt = cur.execute("""
    SELECT max(qid) FROM irc_quotes WHERE nick = ?;
    """, (nick,))
    qid = stmt.fetchone()[0]
    if qid is None:
        raise KeyError("No quotes for user.")
    else:
        return qid


def add_quote(nick: str, message: str) -> str:
    conn = sqlite3.connect(QUOTE_DB)
    with conn:
        cur = conn.cursor()

        try:
            next_id = get_max_qid(cur, nick) + 1
        except KeyError:
            next_id = 1

        cur.execute("""
        INSERT INTO irc_quotes (qid, nick, mesg) VALUES (?, ?, ?);
        """, (next_id, nick, message))
    conn.close()
    return f'Added quote #{next_id} to {nick}.'


def search_quotes(nick: str, mesg: str) -> list[str]:
    conn = sqlite3.connect(QUOTE_DB)
    result = []
    with conn:
        cur = conn.cursor()
        # bubbles exception on no  quotes.
        try:
            max_id = get_max_qid(cur, nick)
            stmt = cur.execute("""
            SELECT qid, nick, mesg FROM irc_quotes
            INNER JOIN (
                SELECT row FROM irc_quotes_search
                WHERE irc_quotes_search MATCH ? AND nick = ?
                ORDER BY RANK
            )
            ON irc_quotes.rowid = row
            LIMIT 25;
            """, ('mesg : '+escape_fts5(mesg), nick))
            for qid, nick, mesg in stmt:
                result.append(f'[{qid}/{max_id}] <{nick}> {mesg}')
        except KeyError:
            result.append('No quotes for user.')

    conn.close()
    return result


def get_quote_by_id(nick: str, num: int) -> str:
    conn = sqlite3.connect(QUOTE_DB)
    result = ''
    with conn:
        cur = conn.cursor()
        try:
            max_id = get_max_qid(cur, nick)
        except KeyError:
            return f'No quotes for {nick}.'

        stmt = cur.execute("""
        SELECT qid, nick, mesg FROM irc_quotes
        WHERE qid = ? AND nick = ?;
        """, (num, nick,))
        row = stmt.fetchone()
        if row is None:
            result = f'No quote [{num}/{max_id}] for {nick}.'
        else:
            result = f'[{row[0]}/{max_id}] <{row[1]}> {row[2]}'
    conn.close()
    return result


def parse_query(q: str) -> list:
    cleanup_nick = re.compile(r'[^a-zA-Z-_]')
    parts = q.split(' ')
    # assume get at first.
    if len(parts) < 3:
        raise TypeError('Unacceptable arguments.')
    else:
        cmd = parts[0]
        nick = cleanup_nick.sub('', parts[1])
        arg = ' '.join(parts[2:])

    if cmd == 'get':
        arg = int(arg)

    return cmd, nick, arg


def main() -> int:
    try:
        args = get_args()
    except ValueError as e:
        log_e(str(e))
        return 1

    try:
        setup_db()
    except sqlite3.Error as e:
        print(':r Could not initialize or open the database for quotes.')
        log_e(str(e))
        return 1

    cmd = args.get(Flag.COMMAND, 'q')
    message = args.get(Flag.MESSAGE, '')
    if message == '':
        print(USAGE.format('', cmd))
    else:
        try:
            cmd, nick, arg = parse_query(message)
        except TypeError as e:
            print(USAGE.format(f'{e} : ', cmd))
            return 0
        except ValueError:
            print(':r Argument is not a positive integer.')
            return 0

        if cmd == 'get':
            print(f':r {get_quote_by_id(nick, arg)}')
        elif cmd == 'add':
            print(f':r {add_quote(nick, arg)}')
        elif cmd == 'search':
            res = search_quotes(nick, arg)
            if len(res) == 0:
                print(':r No Results.')
            elif len(res) == 1:
                print(f':r {res[0]}')
            else:
                url = paste_service(StringIO('\n'.join(res)))
                print(f':r Results: {url}')
        else:
            print(USAGE.format(f'Invalid command {cmd}: ', cmd))

    return 0


if __name__ == '__main__':
    exit(main())
