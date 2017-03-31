#!/usr/bin/env bash
# Copyright 2017 QUiNTZ & prussian
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

orientation='straight'
if [ "$5" = 'gay' ]; then
    orientation='gay'
fi

q="$4"
if [ -z "$q" ]; then
    q="$(curl "http://www.pornmd.com/randomwords?orientation=$orientation" 2>/dev/null | tr -d '"' )"
fi

AMT_RESULTS=3

PORN_MD="http://www.pornmd.com"
PORN_MD_SRCH="$PORN_MD/$orientation/$(URI_ENCODE "${q,,}")"
benis=$(curl "$PORN_MD_SRCH" 2>/dev/null | grep -A 2 -m $AMT_RESULTS '<h2 class="title-video">' | html2 2>/dev/null | grep "/html/body/h2/a/@href=\|/html/body/h2/a/@title=")

IFS=$'\n'

stayMad=0

for i in $benis; do
  values=$(sed 's/^[^=]*=//g' <<< "$i")
  if [ $((stayMad%2)) -eq 0 ]; then
    urls+=($(curl "$PORN_MD$values" -I 2>/dev/null | grep "Location" |  sed 's/^[^: ]*: //g'))
  else
    titles+=($values)
  fi
  stayMad=$((stayMad+1))
done

if [ -z "${titles[0]}" ]; then
  echo ":m $1 Didn't find any results!"
  exit
fi

for i in $(seq 0 $((AMT_RESULTS-1))); do
  [ -z "${titles[$i]}" ] && exit 0 
  echo -e ":m $1 "$'\002'"${titles[$i]}\002 :: ${urls[$i]}"
done


