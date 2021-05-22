#!/usr/bin/env python3
# Copyright (C) 2020  ine
# Copyright (C) 2021  Anthony DeDominic <adedomin@gmail.com>

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

# From Taigabot, with changes to work with neo8ball plus auto-updating code.

from json import load as json_parse, JSONDecodeError, dump as json_dump
from urllib.parse import quote
from urllib.error import URLError, HTTPError
from datetime import datetime, timedelta

from py8ball import main_decorator
from py8ball.http_helpers import request_json
from py8ball.logging import log_e, log_i
from py8ball.environment import get_persistant_location


try:
    DATA_DIR = get_persistant_location()
    DATA = DATA_DIR / 'cg-plugin.json'
except KeyError:
    log_e('$PERSIST_LOC or $XDG_DATA_HOME are not defined.')
    exit(1)


def get_coin_list() -> dict:
    """
    Get the latest list of coins that the coingecko ticker supports.

    Returns:
        JSON response.
    """
    try:
        json = request_json('https://api.coingecko.com/api/v3/coins/list')
        with DATA.open('w') as f:
            json_dump(json, f)
        return json
    except JSONDecodeError:
        log_e('API Error: returned invalid JSON')
        exit(1)
    except FileNotFoundError as e:
        log_e(f'File IO error: make sure {DATA} exists: {e}')
        exit(1)
    except PermissionError as e:
        log_e(f'Make sure {DATA_DIR} is writable: {e}')
        exit(1)
    except Exception as e:
        log_e(str(e))
        exit(1)


def check_coin_list_mtime() -> bool:
    """
    Check if the coin list is up to date.

    Returns:
        True if mtime is older than a week, false otherwise.
    """
    now = datetime.now()
    week_ago = timedelta(weeks=1)
    mtime = datetime.fromtimestamp(DATA.stat().st_mtime)
    return mtime < now - week_ago


try:
    if check_coin_list_mtime():
        log_i('Coin list is stale, getting newer list.')
        COIN_LIST = get_coin_list()
    else:
        with DATA.open('r') as f:
            COIN_LIST = json_parse(f)
except FileNotFoundError:
    COIN_LIST = get_coin_list()
except JSONDecodeError:
    COIN_LIST = get_coin_list()
except Exception as e:
    log_e(str(e))
    exit(1)


COIN_GECKO = 'https://api.coingecko.com/api/v3/coins/'
QUERY = ('localization=false'
         '&tickers=false'
         '&market_data=true'
         '&community_data=false'
         '&developer_data=false'
         '&sparkline=false')


def find_coin_id(q: str) -> (str, str, str):
    """
    Find the given coin by name or symbol from a list.

    Args:
        q: the user provided coin to find.

    Returns:
        A tuple with the cid, ticker symbol and the coin name.

    Raises:
        ValueError when coin is not found.
        JSONDecodeError when the API returns an invalid json doc.
        Exception the request module could have failed as well.
    """
    for coin in COIN_LIST:
        cid = coin.get('id', '')
        symbol = coin.get('symbol', '')
        name = coin.get('name', '')

        if q.lower() == name.lower() or q.lower() == symbol:
            return cid, symbol, name

    raise ValueError(f"'{q}' is not in the coin list.")


def cryptocoin(q: str) -> str:
    """
    Fetch a string suitable for output to IRC about a given coin.

    Args:
        q: the coin the user wants info on.

    Returns:
        Single line about the coin, or an error message.

    Raises:
        KeyError if the CoinGecko API has changed the shape
                 of their JSON.
    """
    if q == '':
        return "Search a coin with: .cg <name>"

    try:
        cid, symbol, name = find_coin_id(q)
    except ValueError:
        return f'Cryptocurrency {q} not found.'

    try:
        data = request_json(f'{COIN_GECKO}{quote(cid)}?{QUERY}')
    except JSONDecodeError:
        log_e('API Error trying to get coin data.')
        return 'Unknown API Error; try again later.'
    except URLError as e:
        log_e(f'CoinGecko down? {e}')
        return 'CoinGecko appears to be down.'
    except HTTPError as e:
        log_e(f'CoinGecko may be blocking us: {e}')
        return 'CoinGecko appears to be misbehaving.'

    # change this to support other (real) coins like eur, jpy, gbp, nok
    real_coin = 'usd'
    current = data['market_data']['current_price'][real_coin]
    high = data['market_data']['high_24h'][real_coin]
    low = data['market_data']['low_24h'][real_coin]
    volume = data['market_data']['total_volume'][real_coin]
    cap = data['market_data']['market_cap'][real_coin]
    change_24h = data['market_data']['price_change_percentage_24h']
    change_7d = data['market_data']['price_change_percentage_7d']
    # change_14d = data['market_data']['price_change_percentage_14d']
    change_30d = data['market_data']['price_change_percentage_30d']
    # change_60d = data['market_data']['price_change_percentage_60d']
    # change_200d = data['market_data']['price_change_percentage_200d']

    output = (f'{name} ({symbol}) '
              f'Current: \x0307${current:,}\x03, '
              f'High: \x0307${high:,}\x03, '
              f'Low: \x0307${low:,}\x03, '
              f'Vol: ${volume:,}, '
              f'Cap: ${cap:,}')

    if change_24h < 0:
        output = output + f', 24h: \x0304{change_24h:.2f}%\x03'
    else:
        output = output + f', 24h: \x0303+{change_24h:.2f}%\x03'

    if change_7d < 0:
        output = output + f', 7d: \x0304{change_7d:.2f}%\x03'
    else:
        output = output + f', 7d: \x0303+{change_7d:.2f}%\x03'

    if change_30d < 0:
        output = output + f', 30d: \x0304{change_30d:.2f}%\x03'
    else:
        output = output + f', 30d: \x0303+{change_30d:.2f}%\x03'

    return output


@main_decorator
def main(*,
         message: str = '',
         command: str = 'cg') -> int:
    """Entrypoint."""
    try:
        if command == 'cg' or command == 'coingecko':
            res = cryptocoin(message)
        else:
            res = cryptocoin(command)

        print(f':r {res}')
    except KeyError as e:
        print(':r Error, CoinGecko API has changed.')
        log_e(f'API Data may have changed: {e}')
        return 1
    except Exception as e:
        print(':r Unknown Error.')
        log_e(f'Unknown Error: {e}')
        return 1
    return 0


if __name__ == '__main__':
    exit(main())
