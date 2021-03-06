#!/usr/bin/env python3
# Copyright (C) 2020  Anthony DeDominic <adedomin@gmail.com>

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

from py8ball import main_decorator
from py8ball.http_helpers import request, request_json
from py8ball.logging import log_w, log_e

from html.parser import HTMLParser as HtmlParser

from datetime import datetime
from pytz import timezone

MLB_DEPRECATED_API = 'http://gd2.mlb.com/components/game/mlb'
API_DATEFMT = "year_%Y/month_%m/day_%d"
MLB_TIMEZONE = 'America/New_York'
OUTGAME_STRING = '{} {} ({}{}) {} {}'


class LatestEventParser(HtmlParser):
    """Parser for latest events from the log."""

    def __init__(self):
        """Init parser."""
        super().__init__(convert_charrefs=True)
        self.__largest_event = -1
        self.latest_event = ''

    def handle_starttag(self, tag, attr):
        """Find event tags."""
        if tag == 'event':
            num = '-999'
            ev = ''

            for attr_name, value in attr:
                if attr_name == 'number':
                    num = int(value)
                if attr_name == 'description':
                    ev = value

            if num >= self.__largest_event and ev != '':
                self.__largest_event = num
                self.latest_event = ev


def get_html(url: str) -> str:
    """Read API XML."""
    with request(url, headers={'Accept':
                               'text/html,application/xhtml+xml'}) as req:
        return req.read().decode('utf8', 'ignore')


def get_api_time_of_day():
    """
    Get the time of day that matches the MLB API Server timezone.

    Returns:
        Current time in America/New_York
    """
    now = datetime.now(timezone(MLB_TIMEZONE))
    return now.strftime(API_DATEFMT)


def get_more_detail(api_path: str, gid: str) -> dict[str, str]:
    """Get more details about a current game."""
    api_gid = 'gid_{}'.format(gid.replace('/', '_').replace('-', '_'))
    detail_linescore = '{}/{}/linescore.json'.format(api_path, api_gid)
    detail_eventlog = '{}/{}/eventLog.xml'.format(api_path, api_gid)

    linescore = request_json(detail_linescore)

    if not isinstance(linescore, dict):
        raise Exception('linescore is not an object')

    try:
        linescore = linescore['data']['game']
    except KeyError:
        raise Exception('Linescore structure is unexpected.')

    # count
    balls = linescore.get('balls', 'unkn')
    strikes = linescore.get('strikes', 'unkn')
    outs = linescore.get('outs', 'unkn')

    runners_onbase = linescore.get('runner_on_base_status', 'unkn')

    try:
        pitcher = linescore['current_pitcher']['last_name']

    except KeyError:
        pitcher = 'unkn'

    try:
        batter = linescore['current_batter']['last_name']
    except KeyError:
        batter = 'unkn'

    # bonus
    latest_event = ''

    try:
        events_xml = get_html(detail_eventlog)
        events = LatestEventParser()
        events.feed(events_xml)
        if events.latest_event != '':
            latest_event = events.latest_event
    except Exception as e:
        latest_event = str(e)

    return {'balls':   balls,
            'strikes': strikes,
            'outs':    outs,
            'onbase':  runners_onbase,
            'pitcher': pitcher,
            'batter':  batter,
            'latest':  latest_event}


def mlb(inp: str = '') -> str:
    """
    Get MLB Games scheduled for Today (in America/New_York TZ).

    Args:
        inp: Input query.

    Returns:
        A String containing the current line-score(s) of Game(s).
        The string is all current games if the input query is a blank string.
    """
    api_base = f'{MLB_DEPRECATED_API}/{get_api_time_of_day()}'
    api_string = f'{api_base}/grid.json'

    try:
        games_today = request_json(api_string)
    except Exception as e:
        log_e(str(e))
        return 'Failed to get games today (Note: gd2 API *is* deprecated).'

    if not isinstance(games_today, dict):
        return 'Failed to get games today: grid.json is not an object.'

    try:
        games = games_today['data']['games']['game']
    except KeyError:
        return 'No Games Today.'

    if not isinstance(games, list):
        games = [games]

    output = []
    for game in games:
        away_team = game.get('away_name_abbrev', '')
        away_score = game.get('away_score', '0')
        if away_score == '':
            away_score = 0

        home_team = game.get('home_name_abbrev', '')
        home_score = game.get('home_score', '0')
        if home_score == '':
            home_score = 0

        inning = game.get('top_inning', '-')
        if inning == 'Y':
            inning = '^'
        elif inning == 'N':
            inning = 'v'
        else:
            inning = '-'

        game_status = game.get('status', '')
        if 'Pre' == game_status[0:3]:
            game_status = game.get('event_time', 'P')
            inning = ''
        elif 'Final' == game_status:
            game_status = 'F'
            inning = ''
        else:
            game_status = game.get('inning', '0')

        outstring = OUTGAME_STRING.format(away_team, away_score,
                                          game_status, inning,
                                          home_team, home_score)

        if inp.lower() == away_team.lower() or \
           inp.lower() == home_team.lower():
            if inning != '':
                try:
                    details = get_more_detail(api_base, game.get('id', 'null'))
                except Exception as e:
                    log_w(f'eventLog API may be broken: {e}')
                    return outstring

                outstring += f' Count: {details["balls"]}-{details["strikes"]}'
                outstring += f' Outs: {details["outs"]}'
                outstring += f' OnBase: {details["onbase"]}'
                outstring += f' Pitcher: {details["pitcher"]}'
                outstring += f' Batter: {details["batter"]}'

                if isinstance(details['latest'], Exception):
                    log_w(f'API For latest events is broken: {details["latest"]}')
                elif details['latest'] != "":
                    return f'{outstring}\nLatest: {details["latest"]}'
            return outstring
        else:
            output.append(outstring)

    if len(output) == 0:
        return 'No Games Today.'
    else:
        return 'Times in EST - ' + ' :: '.join(output)


@main_decorator
def main(*,
         message: str = '',
         command: str = 'mlb') -> int:
    """Entrypoint."""
    if message.startswith('--help'):
        print(f':r usage: {command} [team]')
        exit(0)

    for line in mlb(message).split('\n'):
        print(f':r {line}')


if __name__ == '__main__':
    exit(main())
