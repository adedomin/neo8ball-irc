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
printf -v gid_path '%(gid_%Y_%m_%d_)T' -1
MLB_API="$MLB/$api_path"

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
    if [[ -n "$LIST_GAME" ]]; then
        LIST_GAMES+=':: '$'\002'"${api_data[7]} @ ${api_data[3]}"$'\002'" at ${api_data[1]} EST"
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
        .id'
)

if [[ -n "$LIST_GAME" ]]; then
    echo ":m $1 Games Today $LIST_GAMES"
    exit 0
fi

if [[ -z "$FOUND" ]]; then
    echo ":m $1 $msg is not playing."
    exit 0
fi

echo ":m $1 Away: ${api_data[7]} - ${api_data[9]}" \
    "Home: ${api_data[3]} - ${api_data[5]}" \
    "Status: ${api_data[0]}" \

id="${api_data[10]##*/}"
grid_path+="${id//-/_}"
