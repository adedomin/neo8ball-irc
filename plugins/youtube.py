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

from py8ball import main_decorator
from py8ball.http_helpers import request_json
from py8ball.logging import log_e

from os import environ
from urllib.parse import parse_qsl
from urllib.error import HTTPError
from json import JSONDecodeError, load as json_load


YT_STATS = 'https://www.googleapis.com/youtube/v3/videos'
YT_SEARCH = 'https://www.googleapis.com/youtube/v3/search'


def get_search(q: str, key: str) -> str:
    """Get a Youtube Video ID for a given search query"""
    res = request_json(YT_SEARCH,
                       query={'part': 'snippet',
                              'type': 'video',
                              'maxResults': '1',
                              'q': q, 'key': key})
    return res['items'][0]['id']['videoId']


def get_stats(ids: str, key: str, has_url: bool) -> str:
    """Get The YT stats for a given video as a string"""
    res = request_json(YT_STATS,
                       query={'part': 'snippet,statistics,contentDetails',
                              'id': ids, 'key': key})
    video = res['items'][0]

    retval = (f'\x02{video["snippet"]["title"]}\x02 '
              f'{video["contentDetails"]["duration"][2:].lower()} - ')
    if has_url:
        retval += f'https://youtu.be/{video["id"]} - '
    retval += (f'\x0303\u25b2 {int(video["statistics"]["likeCount"]):,}\x03 '
               f'\x0304\u25bc {int(video["statistics"]["dislikeCount"]):,}\x03 '
               f'\x02Views\x02 {int(video["statistics"]["viewCount"]):,} - '
               f'\x02By\x02 {video["snippet"]["channelTitle"]} '
               f'\x02on\x02 {video["snippet"]["publishedAt"][:10]}')
    return retval


def indexOf(s: str, substr: str) -> int:
    """
    Exception-free str.index().

    Args:
        s: The string to run index method on.
        substr: the substring to match.

    Returns:
        index of the start of substr or -1 for no match.
    """
    try:
        return s.index(substr)
    except ValueError:
        return -1


def find_id(url: str) -> list[str]:
    """
    Find an ID from a regexp matched URL.

    Args:
        url: the youtube URL

    Returns:
        matched video id.

    Raises:
        ValueError if no such video ID could be found.
    """
    urls = url.split(' ')
    for u in urls:
        if (idx := indexOf(u, 'youtu.be/')) != -1:
            # 9 = length of youtu.be/
            return u[idx+9:]
        elif (idx := indexOf(u, 'youtube.com/watch?')) != -1:
            # 18 = length of youtube.com/watch?
            new_u = u[idx+18:]
            for k, v in parse_qsl(new_u):
                if k == 'v':
                    return v
    raise ValueError('Could not find a valid Video ID.')


@main_decorator
def main(*,
         reply: str = '',
         match: str = '',
         message: str = '',
         command: str = 'youtube') -> int:

    if (yt_api_key := environ.get('YOUTUBE_KEY', '')) == '':
        log_e('Plugin requires YOUTUBE_KEY environment variable.')
        print(':r No API Key.')
        return 1

    yt_ignore_list = environ.get('YOUTUBE_IGNORE', '').split()
    if reply in yt_ignore_list:
        return 0

    if message == '' and match == '':
        print(':r usage: {command} query')
        return 0
    elif match != '':
        has_url = True
        ids = find_id(match)
    else:
        has_url = False

    try:
        if not has_url:
            ids = get_search(message, yt_api_key)
        stats = get_stats(ids, yt_api_key, has_url)
        print(f':r {stats}')
    except HTTPError as e:
        print(':r Could not get video details, API Error.')
        log_e(f'Youtube API Key may be invalid: {e}')
        return 1
    except IndexError:
        if not has_url:
            print(f':r No video found for: {message[0:10]}...')
    except KeyError:
        print(':r Could not get video details, API Error.')
        log_e('Youtube Stats API Changed.')
        return 1
    except JSONDecodeError:
        print(':r Could not get video details, API Error.')
        log_e('Youtube Stats API did not return valid JSON.')
        return 1

    return 0


if __name__ == '__main__':
    exit(main())
