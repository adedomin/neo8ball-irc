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

from sys import argv, exit
from html.parser import HTMLParser
from urllib.request import Request, urlopen
from urllib.parse import urlencode, urlparse, parse_qs

SEARCH_ENGINE = "https://html.duckduckgo.com/html/"
LEN_LIMIT = 350


class DdgQueryParser(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.results = []
        self._in_result = False

    def handle_starttag(self, tag, attr):
        css_class = ''
        href = ''
        for k, v in attr:
            if k == 'class':
                css_class = v
            elif k == 'href':
                href = v

        if tag == 'a' and css_class == 'result__snippet' and href != '':
            self._in_result = True
            self.results.append({'url': f'''https:{href}''',
                                 'snippet': ''})
        elif tag == 'b' and self._in_result:
            self.results[-1]['snippet'] += "\x02"

    def handle_endtag(self, tag):
        if tag == 'a' and self._in_result:
            self._in_result = False
        elif tag == 'b' and self._in_result:
            self.results[-1]['snippet'] += "\x02"

    def handle_data(self, data):
        if self._in_result:
            self.results[-1]['snippet'] += data


def request(q):
    param_string = urlencode({'q': q})
    return urlopen(Request(f'{SEARCH_ENGINE}?{param_string}',
                           headers={'User-Agent':
                                    'neo8ball - '
                                    'https://github.com/'
                                    'adedomin/neo8ball-irc',
                                    'Accept-Language': 'en-US,en;q=0.5',
                                    'Accept':
                                    'text/html,application/xhtml+xml'}))


def chunk_read(req):
    '''Read up to 128KiB of data.'''
    for i in range(32):
        yield req.read(4096).decode('utf8', 'ignore')


def get_real_url(indirected_url):
    parsed_query = urlparse(indirected_url)
    parsed_query = parse_qs(parsed_query.query).get('uddg', [])

    if len(parsed_query) == 0:
        return ''
    elif parsed_query[0].startswith('https://duckduckgo.com'):
        ad = urlparse(parsed_query[0])
        ad = parse_qs(ad.query).get('ad_provider', [])
        if len(ad) > 0:
            return ''
        else:
            return parsed_query[0]
    else:
        return parsed_query[0]


def get_answer(q):
    with request(q) as res:
        parser = DdgQueryParser()
        for frag in chunk_read(res):
            if not frag:
                break
            parser.feed(frag)
        res = ''
        snippet = ''
        for result_obj in parser.results:
            parsed_query = get_real_url(result_obj['url'])
            if parsed_query != '':
                res = parsed_query
                snippet = result_obj['snippet']
                break

        if res == '':
            return 'No Results.'
        else:
            if len(snippet) > LEN_LIMIT:
                snippet = f'{snippet[0:LEN_LIMIT]}...'
            return f'''{snippet} - {res}'''


def get_message_arg():
    for arg in argv[1:]:
        values = arg.split('=', maxsplit=1)
        if len(values) == 2 and values[0] == '--message':
            return values[1]
    raise Exception('Expected --message argument.')


if __name__ == "__main__":
    try:
        q = get_message_arg()
    except Exception as e:
        print(f':loge duckduckgo.py: {e}')
        exit(1)

    if q == '':
        print(':r Query is empty.')
        exit(0)

    try:
        res = get_answer(q)
        print(f':r {res.lstrip()}')
    except Exception as e:
        print(f':r {e} - For query {q}')
