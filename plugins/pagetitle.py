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

from html.parser import HTMLParser as HtmlParser
from typing import TextIO

from py8ball import LEN_LIMIT, main_decorator
from py8ball.http_helpers import chunk_read, request
from py8ball.logging import log_d, log_e


class TitleParser(HtmlParser):
    """Parser Fetching <title> tag contents."""

    def __init__(self):
        """Set up parser."""
        super().__init__(convert_charrefs=True)
        self.in_title = False
        self.done = False
        self.title = ''

    def handle_starttag(self, tag, attr):
        """Find title."""
        if tag == 'title':
            self.in_title = True

    def handle_endtag(self, tag):
        """Terminate parser on closing title."""
        if tag == 'title':
            self.in_title = False
            self.done = True

    def handle_data(self, inner_text):
        """Collect title contents."""
        if self.in_title:
            self.title += ' '.join(inner_text.splitlines())

def process_res(res: TextIO) -> str:
    """Process the HTML response."""
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


@main_decorator
def main(*,
         match: str = ''):
    """Entrypoint."""
    url = match
    if not (url.startswith('http://') or url.startswith('https://')):
        log_e(f'Matched text - {url} - is not an http url.')
        return 1

    try:
        with request(url) as res:
            title = process_res(res)
            print(f':r ↑ Title :: {title}')
    # We don't handle non-HTML currently.
    except TypeError:
        log_d('TODO: Handle image, and other data.')
        return 1
    except Exception as e:
        print(f':r {e} - ({url})')

    return 0


if __name__ == '__main__':
    exit(main())
