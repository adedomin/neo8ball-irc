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

FOLLOW_LOCK="$PLUGIN_TEMP/${1//\//|}-mlb/"
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
            if [[ "$msg" == "${msg#* }" ]]; then
                echo ":m $1 --follow argument requires a team."
                exit 0
            else
                msg="${msg#* }"
            fi
        ;;
        -u|--unfollow)
            pushd "$FOLLOW_LOCK" || exit
            # shellcheck disable=SC2035
            kill -15 *
            popd || true
            rm -rf -- "$FOLLOW_LOCK"
            echo ":m $1 Unfollowed game."
            exit 0
        ;;
        -h|--help)
            echo ":m $1 usage: $5 [--(un)follow] [team name or abbv]"
            echo ":m $1 Get stats of currently playing MLB games today."
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
        Pre*) iarrow=; api_data[12]="${api_data[1]}" ;;
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
        | jq -r '
        if (.data.games.game|type=="array") then 
            .data.games.game[]
        else
            .data.games.game
        end | 
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
    [[ -z "$LIST_GAMES" ]] && LIST_GAMES="   No games today."
    printf ':m %s %(%b %d)T EST - %s\n' "$1" -1 "${LIST_GAMES:3}"
    exit 0
fi

if [[ -z "$FOUND" ]]; then
    echo ":m $1 $msg - not playing today."
    exit 0
fi

case "${api_data[0]}" in
    Pre*)
        echo ":m $1 ${BOLD}${api_data[7]}${BOLD}" \
            "@ ${BOLD}${api_data[3]}${BOLD}" \
            "${api_data[1]} EST" 
        exit 0
    ;;
    Final)
        echo ":m $1 Final Score: ${BOLD}${api_data[7]}${BOLD} ${api_data[9]}" \
            "@ ${BOLD}${api_data[3]}${BOLD} ${api_data[5]}"
        exit 0
    ;;
esac

id="${api_data[10]//\//_}"
gid_path="gid_${id//-/_}"
away="${BOLD}${api_data[7]}${BOLD}"
home="${BOLD}${api_data[3]}${BOLD}"

get_linescores() {
    read -r ascore hscore \
        top_inning inning \
        strikes balls outs base \
        pitcher batter status < \
    <(
        curl -s -q "$MLB_API/$gid_path/linescore.json" \
        | jq -r '.data.game | 
            ("0"+.away_team_runs|tonumber|tostring) + " " +
            ("0"+.home_team_runs|tonumber|tostring) + " " +
            .top_inning + " " +
            .inning + " " +
            .strikes + " " +
            .balls + " " +
            .outs + " " +
            .runner_on_base_status + " " +
            .current_pitcher.last_name + " " +
            .current_batter.last_name + " " +
            .status
        '
    )
    if [[ -z "$batter" || "$status" == "Final" ]]; then
        echo ":m $1 Final Score: $away $ascore" \
            "@ $home $hscore"
        rm -rf -- "$FOLLOW_LOCK"
        exit
    fi
    case "$top_inning" in
        Y) iarrow="${GREEN}▴${RESET}" ;;
        N) iarrow="${RED}▾${RESET}" ;;
        *) iarrow="-" ;;
    esac
    read -r event < <( 
        curl -s -q "$MLB_API/$gid_path/eventLog.xml" \
        | awk '
            BEGIN { RS = ">"; max = -999 }

            /<event/ {
                inDesc = ""
                for (i=1; i<=NF; ++i) {
                    if ($i ~ /^number=/) {
                        # len of number=" ... "
                        num = substr($i, 9)
                        num = strtonum(substr(num, 0, length(num) - 1))
                    }
                    else if (inDesc) {
                        if (index($i, "\""))
                            inDesc = ""
                        desc = desc " " $i
                    }
                    else if ($i ~ /^description=/) {
                        inDesc = "true"
                        # len of description="
                        desc = substr($i, 14)
                    }
                }
                if (num > max) {
                    max = num
                    final = substr(desc, 0, index(desc, "\"") - 1)
                }
            }

            END { print final }
        '
    )
    outline="$away $ascore (${inning}${iarrow}) $home $hscore "
    outline+="Count: ${balls:-null}-${strikes:-null} Outs: ${outs:-null} "
    outline+="OnBase: ${base:-null} "
    outline+="Pitcher: ${BOLD}${pitcher:-null}${BOLD} "
    outline+="Batter: ${BOLD}${batter:-null}${BOLD}"
    echo ":m $1 $outline"
    [[ -n "$event" ]] && echo ":m $1 Latest: $event"
}

if [[ -n "$FOLLOW" ]]; then
    get_linescores "$1"
    mkdir "$FOLLOW_LOCK" 2>/dev/null || exit 0
    touch "$FOLLOW_LOCK/$$"
    while true; do
        sleep "${MLB_POLL_RATE:-90}"
        get_linescores "$1"
    done
fi

get_linescores "$1"
