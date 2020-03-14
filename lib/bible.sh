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

# $1 - the channel
# $2 - the search string
print_verses() {
    {
        grep "${grep_args[@]}" -F -i -m 1 -- \
            "$2" "$BIBLE_SOURCE" ||
                printf '%s\n' 'Nothing Found'
    } | {
        declare -i line_cnt=0
        while read -r verse; do
            [[ -z "$start" && "$verse" != 'Nothing Found' ]] && {
                start="${verse%%' |'*}"
                output+="$start${cnt:++"$cnt"} | "
            }
            verse="${verse#*'| '}"
            output+="$verse // "
        done
        while [[ -n "$output" ]] && (( line_cnt++ < 3 )); do
            line="${output:0:350}"
            output="${output:350}"
            printf ":m $1 %s\\n" "$line"
        done
    }
}

q="$4"
for arg in $4; do
    case "$arg" in
        -h|--help)
            echo ":m $1 usage: $5 [+#|-A #|--after=#] [query]"
            echo ":m $1 find or get random verse from either the kjv bible or the quran."
            echo ":m $1 You can optionally select up to 9 more verses after the one found."
            exit 0
        ;;
        +[1-9])
            grep_args=('-A' "${arg#+}")
            cnt="${arg#+}"
        ;;
        -A|--after)
            LAST=a
        ;;
        --after=*)
            case "${arg#*=}" in
                [1-9]) grep_args=('-A' "${arg#*=}")
                       cnt="${arg#*=}" ;;
            esac
        ;;
        *)
            case "$LAST" in
                '') break ;;
                a) case "${arg#*=}" in
                    [1-9]) grep_args=('-A' "$arg")
                           cnt="$arg" ;;
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
elif [[ "$5" = 'demon' ]]; then
    table='demon'
    BIBLE_SOURCE="$DEMON_SOURCE"
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
        print_verses "$1" "$verse"
    else
        printf ":m $1 %s\\n" "${verse:-Nothing Found}"
    fi
elif [[ -n "$BIBLE_SOURCE" && -f "$BIBLE_SOURCE" ]]; then
    
    if [[ -z "$q" ]]; then
        printf ":m $1 %s" "$(shuf -n1 "$BIBLE_SOURCE")"
        exit
    fi

    print_verses "$1" "$q"
else
    echo ":m $1 No bible available"
fi
