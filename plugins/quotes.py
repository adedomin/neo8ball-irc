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
from random import randint
from typing import Optional, Union

from py8ball import main_decorator, guard_large_int
from py8ball.sqlite3_helpers import Sqlite3Manager, escape_fts5
from py8ball.environment import get_persistant_location
from py8ball.logging import log_e
from py8ball.http_helpers import paste_service


USAGE = (':r {}usage: .{} {{ '
         'add nick quotable text | '
         'get nick [num] | '
         'search nick message. }}')


try:
    QUOTE_DB_PATH = get_persistant_location() / 'quote-plugin.db'
    QUOTE_DB = Sqlite3Manager(QUOTE_DB_PATH)
except KeyError:
    log_e('$PERSIST_LOC or $XDG_DATA_HOME are not defined.')
    exit(1)


@QUOTE_DB.apply
def setup_db(*, db: sqlite3.Connection):
    """
    Set up the Table schema for the quotes.py plugin.

    Args:
        db: the database to setup.
    """
    cur = db.cursor()
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


def get_max_qid(cur: sqlite3.Cursor, nick: str) -> int:
    """
    Return the maximum quote id for a given nickname.

    Args:
        cur: Database cursor.
        nick: The nickname to lookup.

    Returns:
        The largest quote id for a given nick.

    Raises:
        KeyError if no quotes exist for a given nickname.
    """
    stmt = cur.execute("""
    SELECT max(qid) FROM irc_quotes WHERE nick = ?;
    """, (nick.lower(),))
    qid = stmt.fetchone()[0]
    if qid is None:
        raise KeyError(f'No quotes for {nick}.')
    else:
        return qid


@QUOTE_DB.apply
def add_quote(nick: str, message: str, *,
              db: sqlite3.Connection) -> int:
    """
    Add a quote to a given nickname.

    Args:
        nick: The nickname associated with the quote.
        message: The quote.
        db: The Database to load the quote into (do not set this).

    Returns:
        the quote id that was added.
    """
    cur = db.cursor()

    try:
        next_id = get_max_qid(cur, nick) + 1
    except KeyError:
        next_id = 1

    cur.execute("""
    INSERT INTO irc_quotes (qid, nick, mesg) VALUES (?, ?, ?);
    """, (next_id, nick.lower(), message))
    return next_id


@QUOTE_DB.apply
def search_quotes(nick: str, mesg: str, *,
                  db: sqlite3.Connection) -> list[str]:
    """
    Search for a given quote for a given nickname.

    Args:
        nick: The nickname to search against.
        mesg: A query used to find a quote.
        db: The Database.

    Returns:
        A list of all matching Quotes (MAX: 25 quotes).

    Raises:
        KeyError if a given user does not have quotes.
    """
    cur = db.cursor()

    # Raises KeyError.
    max_id = get_max_qid(cur, nick)

    result = []
    stmt = cur.execute("""
    SELECT qid, mesg FROM irc_quotes
    INNER JOIN (
        SELECT row FROM irc_quotes_search
        WHERE irc_quotes_search MATCH ? AND nick = ?
        ORDER BY RANK
    )
    ON irc_quotes.rowid = row
    LIMIT 25;
    """, ('mesg : '+escape_fts5(mesg), nick.lower()))
    for qid, mesg in stmt:
        result.append(f'[{qid}/{max_id}] <{nick}> {mesg}')
    return result


@QUOTE_DB.apply
def get_quote_by_id(nick: str,
                    num: Optional[int] = None, *,
                    db: sqlite3.Connection) -> str:
    """
    Get a quote for a given nick by the quote id or a random quote by nick.

    Args:
        nick: The nick the quote id is associated with.
        num: The quote id; if omitted, a random quote is picked.
             If the quote is negative, it will try and calculate it
             starting from the end; e.g. -1 = last quote added.

    Returns:
        The quote.

    Raises:
        KeyError if the given quote id does not exist or
                 the user has no quotes.
    """
    cur = db.cursor()

    max_id = get_max_qid(cur, nick)

    if num is None:
        num = randint(1, max_id)
    elif num < 0:
        num = (max_id + num) + 1

    stmt = cur.execute("""
    SELECT qid, nick, mesg FROM irc_quotes
    WHERE qid = ? AND nick = ?;
    """, (num, nick.lower(),))
    row = stmt.fetchone()
    if row is None:
        raise KeyError(f'No quote [{num}/{max_id}] for {nick}.')
    else:
        return f'[{row[0]}/{max_id}] <{nick}> {row[2]}'


def parse_query(q: str) -> list:
    """Parse a given user's query to decide how to handle it."""
    nick_find = re.compile(r'[a-zA-Z_][a-zA-Z0-9-_]*')
    parts = q.split(' ')

    cmd = parts[0]
    if cmd not in ('add', 'get', 'search'):
        raise TypeError(f'Invalid Command: {cmd}')

    i = 1
    nick = ''
    for n in parts[1:]:
        i += 1
        potential_nick = nick_find.findall(n)
        if len(potential_nick) == 1:
            nick = potential_nick[0]
            break
    if nick == '':
        raise TypeError('No nickname given.')

    rest = ' '.join(parts[i:])

    if rest == '' and cmd == 'get':
        rest = None
    elif rest == '':
        raise TypeError('No argument given.')
    elif cmd == 'get':
        try:
            rest = guard_large_int(rest)
        except ValueError:
            raise TypeError('Numeric argument is not an integer.')

    return cmd, nick, rest


def handle_command(cmd: str, nick: str,
                   arg: Union[str, int]) -> str:
    """
    Handle a parsed query and return a message suitable for IRC.

    Args:
        cmd: The subcommand associated with a query:
             get: a quote for by a specific nickname Quote ID.
             add: a quote for a nickname.
             search: for quotes for a nickname with a given query.
        nick: The nickname associated with the command.
        arg: the argument associated with the command.
             get: a quote id to lookup.
             add: the quote to add to the database.
             search: words/phrase used to find quotes.

    Returns:
        A string to output to IRC.

    Raises:
        ValueError if the command is not a valid command.
    """
    if cmd == 'get':
        try:
            return get_quote_by_id(nick, arg)
        except KeyError as e:
            return str(e)
    elif cmd == 'add':
        qid = add_quote(nick, arg)
        return f'Added quote #{qid} to {nick}.'
    elif cmd == 'search':
        try:
            res = search_quotes(nick, arg)
        except KeyError as e:
            return str(e)

        if len(res) == 0:
            return 'No Results.'
        elif len(res) == 1:
            return res[0]
        else:
            url = paste_service(StringIO('\n'.join(res)))
            return f':r Results: {url}'
    else:
        raise ValueError(f'Invalid command {cmd}')


@main_decorator
def main(*,
         message: str = '',
         command: str = 'q') -> int:
    """Entrypoint."""
    try:
        setup_db()
    except sqlite3.Error as e:
        print(':r Could not initialize or open the database for quotes.')
        log_e(str(e))
        return 1

    if message == '':
        print(USAGE.format('', command))
    else:
        try:
            cmd, nick, arg = parse_query(message)
        except TypeError as e:
            print(USAGE.format(f'{e}: ', command))
            return 0
        except OverflowError as e:
            print(USAGE.format(f'{e}: ', command))
            return 0

        try:
            out = handle_command(cmd, nick, arg)
        except ValueError as e:
            out = USAGE.format(f'{e}: ', command)

        print(f':r {out}')

    return 0


if __name__ == '__main__':
    exit(main())
