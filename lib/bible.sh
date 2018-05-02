#!/bin/bash
# Copyright 2018 Anthony DeDominic <adedomin@gmail.com>
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

q="$4"
for arg in $4; do
    case "$arg" in
        -h|--help)
            echo ":m $1 usage: $5 [-A|-B] [query]"
            echo ":m $1 find or get random verse from either the kjv bible or the quran."
            exit 0
        ;;
        -A|--after)
            LAST=a
        ;;
        -B|--before)
            LAST=b
        ;;
        --after=*)
            case "${arg#*=}" in
                [1-2]) grep_args=('-A' "${arg#*=}") ;;
            esac
        ;;
        --before=*)
            case "${arg#*=}" in
                [1-2]) grep_args=('-B' "${arg#*=}") ;;
            esac
        ;;
        *)
            case "$LAST" in
                '') break ;;
                a) case "${arg#*=}" in
                    [1-2]) grep_args=('-A' "$arg") ;;
                esac ;;
                b) case "${arg#*=}" in
                    [1-2]) grep_args=('-B' "$arg") ;;
                esac ;;
            esac
            unset LAST
        ;;
    esac
    if [[ "$q" == "${q#* }" ]]; then
        q=
        break
    else
        q="${q#* }"
    fi
done

if [[ "$5" = 'quran' ]]; then
    table='quran'
    BIBLE_SOURCE="$QURAN_SOURCE"
else
    table='king_james'
fi

if [[ -n "$BIBLE_DB" && -f "$BIBLE_DB" ]]; then

    if [[ -z "$q" ]]; then
        printf ":m $1 %s\\n" "$(sqlite3 "$BIBLE_DB" <<< "SELECT * FROM $table ORDER BY RANDOM() LIMIT 1;")"
        exit
    fi

    q="${q//\'/\'\'}"
    if [[ "$q" =~ [-.:\{\}] ]]; then
        q="\"$q\""
    fi

    verse="$(sqlite3 "$BIBLE_DB" << EOF
SELECT * FROM $table
WHERE $table
MATCH '$q'
ORDER BY rank
LIMIT 1;
EOF
    )"

    if [[ "${#grep_args[@]}" == 2 && -n "$verse" ]]; then
        grep "${grep_args[@]}" -F -- "$verse" "$BIBLE_SOURCE"
    else
        echo ":m $1 ${verse:-Nothing Found}"
    fi

elif [[ -n "$BIBLE_SOURCE" && -f "$BIBLE_SOURCE" ]]; then

    if [[ -z "$q" ]]; then
        printf ":m $1 %s" "$(shuf -n1 "$BIBLE_SOURCE")"
        exit
    fi

    verse="$(
        grep "${grep_args[@]}" -F -i -m 1 -- \
            "$q" "$BIBLE_SOURCE"
    )"
    echo ":m $1 ${verse:-Nothing Found}"

else

    echo ":m $1 No bible available"

fi
