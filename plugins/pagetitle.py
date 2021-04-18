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


if __name__ == '__main__':
    args = {}
    for arg in argv[1:]:
        values = arg.split('=', maxsplit=1)
        if len(values) == 2:
            args[values[0]] = values[1]

    url = args.get('--match', '')
    if url == '':
        exit(0)

    try:
        with urlopen(Request(url,
                             headers={'User-Agent':
                                      'neo8ball - '
                                      'https://github.com/'
                                      'adedomin/neo8ball-irc',
                                      'Accept':
                                      'text/html,application/xhtml+xml'})) \
        as req:
            parser = TitleParser()
            for html_fragment in chunk_read(req):
                if not html_fragment:
                    break
                parser.feed(html_fragment)
                if parser.done:
                    break
            if parser.title == '':
                parser.title = f'Untitled - {req.geturl()}'

            parser.title = \
                f'{parser.title[0:LIMIT]}{"..." if len(parser.title) > LIMIT else ""}'
            print(f':r ↑ Title :: {parser.title}')
    except Exception as e:
        print(':r {} - ({})'.format(e, url))
        exit(1)
