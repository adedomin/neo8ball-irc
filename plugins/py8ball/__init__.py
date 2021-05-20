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

from enum import Enum
from functools import partial, wraps
from os.path import basename
from pathlib import Path
from os import environ
from sys import argv
from typing import TextIO, Callable
from urllib.parse import urlencode
from urllib.request import Request, urlopen
from json import JSONDecodeError, load as json_parse
import inspect
import sqlite3


LEN_LIMIT = 350


class Flag(Enum):
    '''All possible flags neo8ball currently uses.'''
    REPLY = '--reply'
    NICK = '--nick'
    USER = '--user'
    HOST = '--host'
    CMODE = '--cmode'
    MESSAGE = '--message'
    COMMAND = '--command'
    REGEXP = '--regexp'
    MATCH = '--match'


def get_persistant_location() -> Path:
    """
    Gets either XDG_CONFIG_HOME or the legacy PERSIST_LOC
    Environment variable.

    Returns:
        Pathlib object of the path stored in XDG_CONFIG_HOME

    Raises:
        KeyError when neither varible exists.
    """
    ret = environ.get('XDG_DATA_HOME')
    if ret is None:
        return Path(environ['PERSIST_LOC'])
    else:
        return Path(ret)


def get_args() -> dict[Flag, str]:
    """
    Neo8ball argument parser.

    This is a simplistic argument parser that works for all
    current neo8ball arguments.

    Returns:
        A Dictionary of Flag enums mapping to their textual value.

    Raises:
        ValueError for unknown command line Flag(s).
    """
    args = {}
    for arg in argv[1:]:
        values = arg.split('=', maxsplit=1)
        if len(values) == 2:
            flag = Flag(values[0])
            args[flag] = values[1]
        else:
            raise ValueError(f"'{arg}' did not have a value.")
    return args


def request(url: str,
            query: dict[str, str] = {},
            headers: dict[str, str] = {}) -> TextIO:
    """
    Simple urllib request for GETing values

    Args:
        url: The URL to the resource.
        query: A dict that is urlencoded as a query string.
        headers: A dict of additional headers to pass.

    Returns:
        A TextIO-like file (in fact a urllib response object).

    Raises:
        urllib.error.URLError on protocol issues. (DNS failure).
        urllib.error.HTTPError on issues like 403 forbidden.
    """
    param_string = urlencode(query)
    if param_string:
        param_string = f'?{param_string}'
    req = f'{url}{param_string}'
    header = {'User-Agent':
              'neo8ball - '
              'https://github.com/'
              'adedomin/neo8ball-irc',
              'Accept-Language': 'en-US,en;q=0.5',
              'Accept': 'text/html,application/xhtml+xml',
              **headers}
    return urlopen(Request(req,
                           headers=header))


def chunk_read(f: TextIO, size: int = 4096, times: int = 16) -> str:
    """
    A Chunked reader intended to be used on the
    result of calling request().

    Args:
        f: TextIO-like file that can be chunked.
        size: how many bytes to read per iteration (default 4096).
        times: number of times to read chunks (default 16).

    Returns:
        utf8 encoded strings (errors ignored).
    """
    for i in range(times):
        yield f.read(size).decode('utf8', 'ignore')


def paste_service(f) -> str:
    """
    Upload a file like object to
    images.ghetty.space/paste service.

    Args:
        f: file like object to send.

    Returns:
        URL where the text is reachable.

    Raises:
        urllib.error.* Exceptions.
        ValueError if api_res.status != 'ok'
        KeyError if api_res['href'] does not exist.
    """
    try:
        res = urlopen(url='https://images.ghetty.space/paste',
                      data=f)
        ret = json_parse(res)
        if ret.get('status', '') != 'ok':
            raise ValueError(ret.get('message', 'Unknown error.'))
        return ret['href']
    except JSONDecodeError:
        raise ValueError('API is Down.')


def escape_fts5(query: str) -> str:
    """
    Prevent any of the weird query features of Sqlite3 FTS5 Virtual Tables.

    Args:
        query: The query to be passed to an FTS5 vtable.

    Returns:
        Same string, with double quotes escaped.
        Single quotes are escaped by prepared statements.
    """
    ret = []
    for part in query.split(' '):
        ret.append(f'''"{part.replace('"', '""')}"''')
    return ' '.join(ret)


class LogLevel(Enum):
    """Enum of valid loglevels (commands)."""

    DEBUG = ':logd'
    INFO = ':logi'
    WARNING = ':logw'
    ERROR = ':loge'


def _log(level: LogLevel, out: str):
    callee_frame = inspect.stack()[1]
    callee = basename(callee_frame.filename)
    print(f'{level.value} {callee}: {out}')


log_d = partial(_log, LogLevel.DEBUG)
log_i = partial(_log, LogLevel.INFO)
log_w = partial(_log, LogLevel.WARNING)
log_e = partial(_log, LogLevel.ERROR)


class Sqlite3Manager():
    """
    A helper that will automatically open and close
    a database for a function.
    """

    def __init__(self, dbpath: str = ':memory:', kwarg: str = 'db'):
        """Init state of manager."""
        self.dbpath = dbpath
        self.kwarg = kwarg

    def apply(self, func: Callable) -> Callable:
        """
        Wrap a function such that it will automatically open & close
        A database, set the "db" or kwarg defined argument
        to a given function.

        Example:
            @mymanager.apply
            def my_db_func(arg1, arg2, db):
                pass # ... do stuff with db

        Args:
            func: the function to decorate

        Returns:
            Callable that has been wrapped.
        """
        @wraps(func)
        def wrap(*args, **kwargs):
            db = sqlite3.connect(self.dbpath)
            kwargs[self.kwarg] = db
            try:
                with db:
                    retval = func(*args, **kwargs)
            finally:
                db.close()
            return retval
        return wrap


def main_decorator(func: Callable) -> Callable:
    """
    Decorator that parses commandline arguments and populates them as kwargs.
    The function is decorated with the values from the command line
    that match the function signature of the callable.

    If you want, say --message=value only, define your main()
    as main(message): or preferably,
    as main(*, message: str = 'default') -> int:
    
    If you want the "command" name, you'd use main(*, command):
    Regexps would be main(*, match, regexp)
    
    See:
        Flags: for all command line arguments possible. strip leading double
               slash for the kwarg name to use in your main().

    Example:
        @main_decorator
        def main(*, command, message, nick, reply, ...etc):
            print(command)
            print(message)
            # ... etc

    Args:
        func: A "main" function for a neo8ball plugin that uses pure kwargs.


    Returns:
        Wrapped callable.
    """
    argspec = func.__code__.co_varnames

    @wraps(func)
    def w() -> int:
        try:
            args = get_args().items()
        except ValueError as e:
            log_e(str(e))
            return 1

        new_args = {}
        for flag, value in args:
            real_flag = flag.value[2:]
            if real_flag in argspec:
                new_args[real_flag] = value
        ret = func(**new_args)

        return ret
    return w
