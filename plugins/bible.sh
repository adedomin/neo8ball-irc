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

# $1 - the search string
print_verses() {
    {
        grep "${grep_args[@]}" -F -i -m 1 -- \
            "$1" "$BIBLE_SOURCE" ||
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
            printf ':r %s\n' "$line"
        done
    }
}

for arg; do
    case "$arg" in
        --message=*) q="${arg#*=}" ;;
        --command=*) command="${arg#*=}" ;;
    esac
done

while [[ -n "$q" ]]; do
    arg="${q%% *}"

    case "$arg" in
        -h|--help)
            echo ":r usage: $command [+#|-A #|--after=#] [query]"
            echo ":r find or get random verse from either the kjv bible or the quran."
            echo ":r You can optionally select up to 9 more verses after the one found."
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
        '') ;;
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

    if [[ "${q#"$arg" }" == "$q" ]]; then
        q=
    else
        q="${q#"$arg" }"
    fi
done

if [[ "$command" = 'quran' ]]; then
    table='quran'
    BIBLE_SOURCE="$QURAN_SOURCE"
else
    table='king_james'
fi

if [[ -n "$BIBLE_DB" && -f "$BIBLE_DB" ]]; then

    if [[ -z "$q" ]]; then
        printf ':r %s\n' "$(sqlite3 "$BIBLE_DB" <<< "SELECT * FROM $table ORDER BY RANDOM() LIMIT 1;")"
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
        print_verses "$verse"
    else
        printf ':r %s\n' "${verse:-Nothing Found}"
    fi
elif [[ -n "$BIBLE_SOURCE" && -f "$BIBLE_SOURCE" ]]; then
    
    if [[ -z "$q" ]]; then
        printf ':r %s\n' "$(shuf -n1 "$BIBLE_SOURCE")"
        exit
    fi

    print_verses "$q"
else
    printf ':r No bible available\n'
fi
