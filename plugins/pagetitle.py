#!/usr/bin/env python3
# Copyright (c) 2020, Anthony DeDominic <adedomin@gmail.com>
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

from sys import argv, exit
from html.parser import HTMLParser as HtmlParser
from py8ball import LEN_LIMIT, chunk_read, request, log_d, log_e


class TitleParser(HtmlParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.in_title = False
        self.done = False
        self.title = ''

    def handle_starttag(self, tag, attr):
        if tag == 'title':
            self.in_title = True

    def handle_endtag(self, tag):
        if tag == 'title':
            self.in_title = False
            self.done = True

    def handle_data(self, inner_text):
        if self.in_title:
            self.title += inner_text


def process_res(res):
    content_type = res.headers.get('Content-Type', '')
    if 'html' not in content_type:
        raise TypeError('Not (X)HTML')

    parser = TitleParser()
    for html_fragment in chunk_read(res, size=4096, times=10):
        if not html_fragment:
            break
        parser.feed(html_fragment)
        if parser.done:
            break

    out = parser.title
    if out == '':
        out = f'Untitled - {res.geturl()}'
    elif len(out) > LEN_LIMIT:
        out = f'{out[0:LEN_LIMIT]}...'
    return out


def main(url):
    try:
        with request(url) as res:
            title = process_res(res)
            print(f':r ↑ Title :: {title}')
    # We don't handle non-HTML currently.
    except TypeError:
        log_d('TODO: Handle image, and other data.')
    except Exception as e:
        print(f':r {e} - ({url})')


def get_match_arg():
    for arg in argv[1:]:
        values = arg.split('=', maxsplit=1)
        if len(values) == 2 and values[0] == '--match':
            return values[1]
    raise Exception('Expected --match argument.')


if __name__ == '__main__':
    try:
        url = get_match_arg()
    except Exception as e:
        log_e(str(e))
        exit(1)

    if not (url.startswith('http://') or url.startswith('https://')):
        log_e(f'Matched text - {url} - is not an http url.')
        exit(1)
    else:
        main(url)
