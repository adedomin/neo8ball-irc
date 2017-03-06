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

if [ "$5" = 'quran' ]; then
    BIBLE_SOURCE="$QURAN_SOURCE"
fi

if [ -z "$BIBLE_SOURCE" ] || [ ! -f "$BIBLE_SOURCE" ]; then
    echo ":m $1 No bible or quran available." 
    exit 0
fi

if [ -z "$4" ]; then
    printf ":m $1 %s\n" "$(shuf -n1 "$BIBLE_SOURCE")"
    exit 0
fi

printf ":m $1 %s\n" "$(grep -F -m 1 -i "$4" "$BIBLE_SOURCE")"
