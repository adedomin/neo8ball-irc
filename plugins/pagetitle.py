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

from sys import argv, exit, stderr
from html.parser import HTMLParser as HtmlParser
from urllib.request import Request, urlopen

LIMIT = 350


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


def chunk_read(req):
    for i in range(10):
        yield req.read(4096).decode('utf8', 'ignore')


def process_res(res):
    content_type = res.headers.get('Content-Type', '')
    if 'html' not in content_type:
        raise TypeError('Not (X)HTML')

    parser = TitleParser()
    for html_fragment in chunk_read(res):
        if not html_fragment:
            break
        parser.feed(html_fragment)
        if parser.done:
            break
    if parser.title == '':
        parser.title = f'Untitled - {res.geturl()}'

    return f'{parser.title[0:LIMIT]}{"..." if len(parser.title) > LIMIT else ""}'


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
        print(f':loge pagetitle.py: {str(e)}')
        exit(1)

    if not (url.startswith('http://') or url.startswith('https://')):
        print(f':loge pagetitle.py: Matched text - {url} - is not an http url.')
        exit(1)

    try:
        with urlopen(Request(url,
                             headers={'User-Agent':
                                      'neo8ball - '
                                      'https://github.com/'
                                      'adedomin/neo8ball-irc',
                                      'Accept':
                                      'text/html,application/xhtml+xml'})) \
        as res:
            title = process_res(res)
            print(f':r ↑ Title :: {title}')
    # We don't handle non-HTML currently.
    except TypeError:
        print(':logd pagetitle.py: TODO: Handle image, and other data.')
        exit(0)
    except Exception as e:
        print(':r {} - ({})'.format(e, url))
        exit(1)
