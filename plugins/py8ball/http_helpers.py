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

from typing import TextIO, Optional
from urllib.parse import urlencode
from urllib.request import Request, urlopen
from json import JSONDecodeError, load as json_parse


def request(url: str,
            query: Optional[dict[str, str]] = None,
            headers: Optional[dict[str, str]] = {}) -> TextIO:
    """
    GET a url with an optional query string and custom headers.

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
    param_string = f'?{urlencode(query)}' if query is not None else ''
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


def request_json(url: str,
                 query: Optional[dict[str, str]] = None,
                 headers: Optional[dict[str, str]] = {}) -> dict:
    """
    GET and parse a JSON object.

    Args:
        url: The URL to the resource.
        query: A dict that is urlencoded as a query string.
        headers: A dict of additional headers to pass.

    Returns:
        Dict of the parsed json request.

    Raises:
        json.JSONDecodeError if invalid json response.
    """
    header = {'Accept': 'application/json',
              **headers}
    with request(url, query, header) as res:
        return json_parse(res)


def chunk_read(f: TextIO,
               size: int = 4096,
               times: int = 16) -> str:
    """
    Chunk a file-like object into consumable bites.

    Args:
        f: TextIO-like file that can be chunked.
        size: how many bytes to read per iteration (default 4096).
        times: number of times to read chunks (default 16).

    Returns:
        utf8 encoded strings (errors ignored).
    """
    for i in range(times):
        yield f.read(size).decode('utf8', 'ignore')


def paste_service(f: TextIO) -> str:
    """
    Upload a file like object to images.ghetty.space/paste service.

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
