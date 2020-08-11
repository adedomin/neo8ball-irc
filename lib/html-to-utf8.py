#!/usr/bin/env python3
# Copyright 2020 Anthony DeDominic <adedomin@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

from sys import stdin, argv
from html.parser import HTMLParser


def tag_to_irc(tag):
    if tag == 'b':
        return '\x02'
    elif tag == 'i':
        return '\x1d'
    elif tag == 'u':
        return '\x1f'
    elif tag == 's':
        return '\x1e'


class StdoutParser(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.output_text = ''

    def handle_starttag(self, tag, attr):
        val = tag_to_irc(tag)
        if val:
            self.output_text += val

    def handle_endtag(self, tag):
        val = tag_to_irc(tag)
        if val:
            self.output_text += val

    def handle_data(self, inner_text):
        self.output_text += inner_text


if __name__ == '__main__':
    limit = int(argv[1]) if len(argv) > 1 else -1

    parser = StdoutParser()

    for line in stdin:
        parser.feed(line.replace('\n', ' '))

    print(parser.output_text)
