#!/usr/bin/env bash
# Copyright 2017 prussian <genunrest@gmail.com>
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

declare -A COLOR
KCOL=$'\003'
COLOR=(
['white']=$'\003'"00,00"
['black']=$'\003'"01,01"
['navy']=$'\003'"02,02"
['green']=$'\003'"03,03"
['red']=$'\003'"04,04"
['brown']=$'\003'"05,05"
['purple']=$'\003'"06,06"
['olive']=$'\003'"07,07"
['yellow']=$'\003'"08,08"
['lime']=$'\003'"09,09"
['teal']=$'\003'"10,10"
['cyan']=$'\003'"11,11"
['blue']=$'\003'"12,12"
['fuchsia']=$'\003'"13,13"
['grey']=$'\003'"14,14"
['lightgrey']=$'\003'"15,15"
)

MOOSE="http://captmoose.club/moose/$(URI_ENCODE "$4")"

if ! mkdir "$MOOSE_LOCK"; then
    echo ":mn $3 Please wait for the current moose to finish."
    exit 0
fi

while read -r -a line; do
    out=''
    for (( i=0; i<${#line[@]}; i++ )); do
        if [ "${line[$i]}" = 'transparent' ]; then
            out+=' '
        else
            out+="${COLOR[${line[$i]}]}@${KCOL}"
        fi
    done
    echo ":r PRIVMSG $1 :$out"
    sleep "0.3s"
done < <( 
    curl "$MOOSE" -f 2>/dev/null \
    | jq -r '.moose[] | join(" ")'
)

rmdir "$MOOSE_LOCK"
