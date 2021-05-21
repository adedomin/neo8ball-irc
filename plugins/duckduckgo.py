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

from py8ball import \
    request, chunk_read, main_decorator

from typing import NamedTuple
from sys import exit
from html.parser import HTMLParser
from urllib.parse import urlparse, parse_qsl

SEARCH_ENGINE = "https://html.duckduckgo.com/html/"
LEN_LIMIT = 350


class DdgResult(NamedTuple):
    url: str
    snippet: str


def get_real_url(indirected_url: str) -> str:
    '''
    Returns the true URL from a search.

    Args:
        indirected_url: The url from the web search.

    Returns:
        The actual clean URL.

    Raises:
        ValueError for irredemably bad URLs.
    '''
    url = ''
    parsed_query = urlparse(indirected_url)
    for k, v in parse_qsl(parsed_query.query):
        if k == 'uddg':
            url = v
            break

    if url == '':
        raise ValueError('Empty query')
    elif url.startswith('https://duckduckgo.com'):
        ad = urlparse(url)
        for k, v in parse_qsl(ad.query):
            if k == 'ad_provider':
                raise ValueError('Ad')
    return url


class DdgQueryParser(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self._url: str = ''
        self._snippet: str = ''
        self.result: DdgResult = None
        self._in_result = False

    def handle_starttag(self, tag, attr):
        if self.result:
            return

        css_class = ''
        href = ''
        for k, v in attr:
            if k == 'class':
                css_class = v
            elif k == 'href':
                href = v

        if tag == 'a' and css_class == 'result__snippet' and href != '':
            try:
                self._url = get_real_url(f'https:{href}')
                self._in_result = True
            except ValueError:
                pass

        # ddg puts <b> tags around our search terms.
        # let us make them bold.
        elif tag == 'b' and self._in_result:
            self._snippet += "\x02"

    def handle_endtag(self, tag):
        if tag == 'a' and self._in_result:
            self.result = DdgResult(self._url, self._snippet)
            self._in_result = False

        # Terminate the bold text.
        elif tag == 'b' and self._in_result:
            self._snippet += "\x02"

    def handle_data(self, data):
        if self._in_result:
            self._snippet += data


def get_answer(q: str) -> str:
    with request(SEARCH_ENGINE, {'q': q}) as res:
        parser = DdgQueryParser()
        # Up to 128KiB read.
        for frag in chunk_read(res, size=4096, times=32):
            if not frag:
                break
            parser.feed(frag)
            if parser.result:
                break

        if parser.result:
            url, snippet = parser.result
            if len(snippet) > LEN_LIMIT:
                snippet = f'{snippet[0:LEN_LIMIT]}...'
            return f'''{snippet} - {url}'''
        else:
            return 'No result.'


@main_decorator
def main(*,
         message: str = '--help',
         command: str = 'ddg') -> int:
    query = message
    if query.startswith('--help'):
        print(f':r {command} [--help] query')
        exit(0)

    if command == 'mdn':
        query += ' site:https://developer.mozilla.org/en-US'

    try:
        res = get_answer(query)
        print(f':r {res.lstrip()}')
    except Exception as e:
        print(f':r {e} - For query {query}')
        return 1
    return 0


if __name__ == '__main__':
    exit(main())
