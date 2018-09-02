#!/bin/bash
# Copyright 2017 dimattiami, Anthony DeDominic <adedomin@gmail.com>
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

declare -i COUNT=1
LAST=
msg="$4"
query_type='@id = "Verb" or @id = "Noun" or @id = "Adjective"'
for arg in $4; do
    case "$arg" in
        -c|--count)
            LAST='c'
        ;;
        --count=*)
            echo "${arg#*=}" >&2
            [[ "${arg#*=}" =~ ^[1-3]$ ]] &&
                COUNT="${arg#*=}"
        ;;
        -d|--defintion)
            LAST='d'
        ;;
        --definition=*)
            [[ "${arg#*=}" =~ ^(1[0-9]|[1-9])$ ]] &&
                declare -i DEFINITION="${arg#*=}"
        ;;
        -n|--noun)
            type_of=Noun
            query_type='@id = "Noun"'
        ;;
        -v|--verb)
            type_of=Verb
            query_type='@id = "Verb"'
        ;;
        -a|--adjective)
            type_of=Adjective
            query_type='@id = "Adjective"'
        ;;
        -h|--help)
            printf '%s\n' \
                ":m $1 usage: $5 [-nva] [--defintion=#-to-get] [--count=#-to-ret] query"
            printf '%s\n' \
                ":m $1 defines a given word. -n:--noun -v:--verb -a:--adjective"
            exit 0
        ;;
        *)
            [ -z "$LAST" ] && break
            if [ "$LAST" = 'd' ]; then
                declare -i DEFINITION
                [[ "$arg" =~ ^(1[0-9]|[1-9])$ ]] &&
                    declare -i DEFINITION="$arg"
            else
                [[ "$arg" =~ ^[1-3]$ ]] &&
                    COUNT="$arg"
            fi
            unset LAST
        ;;
    esac
    if [[ "$msg" == "${msg#* }" ]]; then
        msg=
        break
    else
        msg="${msg#* }"
    fi
done

if [[ -z "$msg" ]]; then
    echo ":mn $3 This command requires a search query"
    exit 0
fi

DICTIONARY="https://en.wiktionary.org/w/index.php?title=$(URI_ENCODE "${msg}")&printable=yes"

mapfile -t defs < <(
    xpath -q -e \
'//div[@class = "mw-parser-output"]/*/span['"$query_type"']/ancestor::*/following-sibling::ol[1]/li' <(
        curl --silent --fail "$DICTIONARY"
    ) | sed '
        s@</\?\(li\|a\|span\)[^>]*>@@g
        /<[^>]*>/d
    '
)

print_def() {
    printf ':m %s \002%s\002 [%d/%d] :: %s\n' \
        "$1" "${type_of:+$type_of: }${msg:0:100}" "$2" "$3" \
        "${definition}"
}

declare -i i def_len="${#defs[@]}"
(( COUNT > def_len )) && COUNT="$def_len"
if (( def_len > 0 )); then
    if [[ -z "$DEFINITION" ]]; then
        for (( i=0; i < COUNT; ++i )); do
            definition="${defs[i]}"
            (( ${#definition} > 400 )) &&
                definition="${definition:0:400}..."
            print_def "$1" "$(( i + 1 ))" "$def_len"
        done
    else
        (( DEFINITION > def_len )) &&
            DEFINITION=1
        definition="${defs[DEFINITION - 1]}"
        print_def "$1" "$DEFINITION" "$def_len"
    fi
    echo ":mn $3 See More: $DICTIONARY"
else
    echo ":m $1 No definition found"
fi
