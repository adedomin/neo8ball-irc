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
    limit = int(argv[2]) if len(argv) > 2 else -1

    try:
        with urlopen(Request(argv[1],
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
            if limit != -1:
                parser.title = \
                    f'{parser.title[0:limit]}{"..." if len(parser.title) > limit else ""}'
            print(parser.title)
    except Exception as e:
        print('{} - ({})'.format(e, argv[1]))
        exit(1)
