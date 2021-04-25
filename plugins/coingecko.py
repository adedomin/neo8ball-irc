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
from py8ball import request, log_e, get_args, Flag, get_persistant_location
from urllib.parse import quote
from datetime import datetime, timedelta


WEEK_AGO = timedelta(weeks=1)
NOW = datetime.now()
try:
    DATA_DIR = get_persistant_location()
    DATA = DATA_DIR / 'cg-plugin.json'
except KeyError:
    log_e('$PERSIST_LOC or $XDG_DATA_HOME are not defined.')
    exit(1)


def get_coin_list():
    try:
        with request('https://api.coingecko.com/api/v3/coins/list') as res:
            with DATA.open('w') as f:
                json = json_parse(res)
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


try:
    # update this every week
    mtime = datetime.fromtimestamp(DATA.stat().st_mtime)
    if mtime < NOW - WEEK_AGO:
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
QUERY = 'localization=false&tickers=false&market_data=true&community_data=false&developer_data=false&sparkline=false'


def consume_api(cid):
    with request(f'{COIN_GECKO}{quote(cid)}?{QUERY}') as res:
        return json_parse(res)


def find_coin_id(q):
    for coin in COIN_LIST:
        cid = coin.get('id', '')
        symbol = coin.get('symbol', '')
        name = coin.get('name', '')

        if q.lower() == name.lower() or q.lower() == symbol:
            return cid, symbol, name

    return False


def cryptocoin(q):
    if q == "":
        return "Search a coin with: .cg <name>"

    coin = find_coin_id(q)

    if coin is False:
        return f'Cryptocurrency {q} not found.'
    else:
        cid, symbol, name = coin

    try:
        data = consume_api(cid)
    except JSONDecodeError:
        log_e('API Error trying to get coin data.')
        return 'Unknown API Error; try again later.'
    except Exception as e:
        log_e(f'Some Connection Error: {e}')
        return 'Unknwon API Error.'

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


if __name__ == '__main__':
    try:
        args = get_args()
    except ValueError as e:
        log_e(str(e))
        exit(1)

    cmd = args.get(Flag.COMMAND, '')
    message = args.get(Flag.MESSAGE, '')

    try:
        if cmd == 'cg' or cmd == 'coingecko':
            res = cryptocoin(message)
        else:
            res = cryptocoin(cmd)

        print(f':r {res}')
    except KeyError as e:
        log_e(f'API Data may have changed: {e}')
        exit(1)
    except Exception as e:
        log_e(f'Unknown Error: {e}')
        exit(1)
