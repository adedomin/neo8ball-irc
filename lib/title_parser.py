#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# Copyright (C) 2020  Anthony DeDominic <adedomin@gmail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

import re
from html.entities import html5 as char_entities


TitleTokenizer = re.compile('''(?x)
 (?P<WHITESPACE>\\s+)
|(?P<TITLE>[<][/]?\\s*[tT][iI][tT][lL][eE][^>]*[>])
|(?P<WORDS>[^<>&"'\\s]+)
|(?P<DEC_CHAR_ENT>
  [&][#]
   (?P<dec_code_value>\\d+)
  ;
 )
|(?P<HEX_CHAR_ENT>
  [&][#]x
   (?P<hex_code_value>[a-fA-F0-9]+)
  ;
 )
|(?P<WORD_CHAR_ENT>
  [&]
   (?P<word_code_value>\\w+;)
 )
|(?P<OTHER_TAG> # technically not valid
  [<][/]?\\s*
   (?P<tag_name>[\\w!]+)
  [^>]*[>])
|(?P<INVALID>.)
''')


def tokenize_title_chunk(html_chunk):
    for match_obj in re.finditer(TitleTokenizer, html_chunk):
        typeof = match_obj.lastgroup
        if typeof == 'OTHER_TAG':
            value = match_obj.group('tag_name')
        elif typeof == 'WHITESPACE':
            value = ' '
        elif typeof == 'DEC_CHAR_ENT':
            value = match_obj.group('dec_code_value')
        elif typeof == 'HEX_CHAR_ENT':
            value = match_obj.group('hex_code_value')
        elif typeof == 'WORD_CHAR_ENT':
            value = match_obj.group('word_code_value')
        else:
            value = match_obj.group()

        yield (typeof, value)


def parse_title_chunk(tokens):
    in_title = False
    reduce = ''

    for tkn in tokens:
        if not in_title and tkn[0] == 'TITLE':
            in_title = True
        elif in_title and tkn[0] == 'TITLE':
            break
        elif in_title:
            if tkn[0] == 'DEC_CHAR_ENT' or tkn[0] == 'HEX_CHAR_ENT':
                try:
                    cvalue = chr(int(tkn[1],
                                     10
                                     if tkn[0] == 'DEC_CHAR_ENT'
                                     else 16))
                except ValueError:
                    cvalue = '�'
                reduce = reduce + cvalue
            elif (tkn[0] == 'WORD_CHAR_ENT'):
                try:
                    cvalue = char_entities[tkn[1]]
                except KeyError:
                    cvalue = '�'
                reduce = reduce + cvalue
            elif tkn[0] == 'OTHER_TAG':
                tag = tkn[1].lower()
                if tag == 'b':
                    reduce = reduce + '\x02'
                elif tag == 'i':
                    reduce = reduce + '\x1d'
                elif tag == 'u':
                    reduce = reduce + '\x1f'
                elif tag == 's':
                    reduce = reduce + '\x1e'
            else:
                reduce = reduce + tkn[1]

    return reduce


def parse_title(html, limit=-1):
    ret = parse_title_chunk(tokenize_title_chunk(html))
    if limit != -1:
        return f'{ret[0:limit]}...'
    return ret


if __name__ == '__main__':
    from sys import argv
    from urllib.request import urlopen

    limit = int(argv[2]) if len(argv) > 2 else -1

    with urlopen(argv[1]) as req:
        print(parse_title(req.read(4096)
                             .decode('utf-8', 'ignore'),
                          limit=limit))
