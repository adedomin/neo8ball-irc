#!/bin/bash
# Copyright 2017 Anthony DeDominic <adedomin@gmail.com>
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

MLB='http://gd2.mlb.com/components/game/mlb'
printf -v api_path '%(year_%Y/month_%m/day_%d)T' -1
MLB_API="$MLB/$api_path"
BOLD=$'\002'
GREEN=$'\003''03'
RED=$'\003''04'
RESET=$'\003'

msg="$4"
for arg in $4; do
    case "$arg" in
        -f|--follow)
            FOLLOW=1
            msg="${msg#* }"
        ;;
        -h|--help)
            echo ":m $1 usage: $5 [team name or abbv]"
            echo ":m $1 Get stats of currently playing games today."
            exit 0
        ;;
        *)
            break
        ;;
    esac
done

if [[ -z "$msg" ]]; then
    LIST_GAME=1
fi

while IFS=',' read -r -a api_data; do
    case "${api_data[11]}" in
        Y) iarrow="${GREEN}▴${RESET}" ;;
        N) iarrow="${RED}▾${RESET}" ;;
        *) iarrow="-" ;;
    esac
    case "${api_data[0]}" in
        Pre*) iarrow=; api_data[12]='P' ;;
        Final) iarrow=; api_data[12]='F' ;;
    esac
    if [[ -n "$LIST_GAME" ]]; then
        LIST_GAMES+=":: ${BOLD}${api_data[7]}${BOLD} ${api_data[9]} "
        LIST_GAMES+="(${api_data[12]}$iarrow) "
        LIST_GAMES+="${BOLD}${api_data[3]}${BOLD} ${api_data[5]} "
    else 
        for data in "${api_data[@]:2}"; do
            if [[ "${msg,,}" == "${data,,}" ]]; then
                FOUND=1
                break 2
            fi
        done
    fi
done < <(
    curl -s -q "$MLB_API/grid.json" \
    | jq -r '.data.games.game[] | 
        .status + "," +
        .event_time + "," +
        .home_team_name + "," +
            .home_name_abbrev + "," + 
            .home_code + "," +
            (("0"+.home_score|tonumber)|tostring) + "," + 
        .away_team_name + "," +
            .away_name_abbrev + "," +
            .away_code + "," + 
            (("0"+.away_score|tonumber)|tostring) + "," +
        .id + "," +
        .top_inning + "," +
        (("0"+.inning|tonumber)|tostring)'
)

if [[ -n "$LIST_GAME" ]]; then
    printf ":m $1 %(%b-%d)T - %s\n" -1 "${LIST_GAMES:3}"
    exit 0
fi

if [[ -z "$FOUND" ]]; then
    echo ":m $1 $msg - not playing today."
    exit 0
fi
    
id="${api_data[10]//\//_}"
gid_path="gid_${id//-/_}"

if [[ "${api_data[12]}" != 'P' || 
      "${api_data[0]}" != 'F' ]]
then
    game_data="$(curl -s -q "$MLB_API/$gid_path/linescore.json")"
    if [[ -n "$game_data" ]]; then
        batter="$(
            jq -r .data.game.current_batter.last_name <<< "$game_data"
        )"
        pitcher="$(
            jq -r .data.game.current_pitcher.last_name <<< "$game_data"
        )"
        strikes="$(
            jq -r .data.game.strikes <<< "$game_data"
        )"
        balls="$(
            jq -r .data.game.balls <<< "$game_data"
        )"
        outs="$(
            jq -r .data.game.outs <<< "$game_data"
        )"
        base="$(
            jq -r .data.game.outs <<< "$game_data"
        )"
    fi
fi

echo ":m $1 ${BOLD}${api_data[7]}${BOLD} ${api_data[9]}" \
    "(${api_data[12]}$iarrow)" \
    "${BOLD}${api_data[3]}${BOLD} ${api_data[5]} -" \
    "Count: ${strikes:-0}-${balls:-0} Outs: ${outs:-0} OnBase: ${base:-0}" \
    "Batter: ${batter:-UNKN} Pitcher: ${pitcher:-UNKN}"
