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
from functools import partial
from os.path import basename
from pathlib import Path
from os import environ
from sys import argv
from typing import Dict, TextIO
from urllib.parse import urlencode
from urllib.request import Request, urlopen
from json import JSONDecodeError, load as json_parse
import inspect


LEN_LIMIT = 350


class Flag(Enum):
    '''All possible flags neo8ball currently uses'''
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
    '''
    Gets either XDG_CONFIG_HOME or the legacy PERSIST_LOC
    Environment variable.

    Returns:
        Pathlib object of the path stored in XDG_CONFIG_HOME

    Raises:
        KeyError when neither varible exists.
    '''
    ret = environ.get('XDG_DATA_HOME')
    if ret is None:
        return Path(environ['PERSIST_LOC'])
    else:
        return Path(ret)


def get_args() -> Dict[Flag, str]:
    '''
    Neo8ball argument parser.

    This is a simplistic argument parser that works for all
    current neo8ball arguments.

    Returns:
        A Dictionary of Flag enums mapping to their textual value.

    Raises:
        ValueError for unknown command line Flag(s).
    '''
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
            query: Dict[str, str] = {},
            headers: Dict[str, str] = {}) -> TextIO:
    '''
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
    '''
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
    '''
    A Chunked reader intended to be used on the
    result of calling request().

    Args:
        f: TextIO-like file that can be chunked.
        size: how many bytes to read per iteration (default 4096).
        times: number of times to read chunks (default 16).

    Returns:
        utf8 encoded strings (errors ignored).
    '''
    for i in range(times):
        yield f.read(size).decode('utf8', 'ignore')


def paste_service(f) -> str:
    '''
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
    '''
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
    '''
    Prevent any of the weird query features of Sqlite3 FTS5 Virtual Tables.

    Args:
        query: The query to be passed to an FTS5 vtable.

    Returns:
        Same string, with double quotes escaped.
        Single quotes are escaped by prepared statements.
    '''
    ret = []
    for part in query.split(' '):
        ret.append(f'''"{part.replace('"', '""')}"''')
    return ' '.join(ret)


class LogLevel(Enum):
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
