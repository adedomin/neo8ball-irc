#!/usr/bin/env bash
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

responses=(
'Signs point to yes.'
'Yes.'
'Reply hazy, try again'.
'Without a doubt.'
'My sources say no.'
'As I see it, yes.'
'You may rely on it.'
'Concentrate and ask again.'
'Outlook not so good.'
'It is decidedly so.'
'Better not tell you now.'
'Very doubtful.'
'Yes - definitely.'
'It is certain.'
'Cannot predict now.'
'Most likely.'
'Ask again later.'
'My reply is no.'
'Outlook good.'
"Don't count on it."
)

# New neo8ball command line interface is dynamic.
# We will use the new neo8ball `:reply` command so we don't need --reply flag.
#  * The --reply flag comes with the channel to send replies to.
for arg; do
    case "$arg" in
        --nick=*)    nick="${arg#*=}" ;;
        --message=*) msg="${arg#*=}" ;;
        --command=*) command="${arg#*=}" ;;
    esac
done

# this is an example of a proper argument parser from a messge.
while [[ -n "$msg" ]]; do
    arg="${msg%% *}"

    case "$arg" in
        -y|--yes-no)
            YN=1
        ;;
        -h|--help)
            echo ":r usage: $command [-y --yes-no] query? [y/n]"
            echo ":r usage: $command <choice a> or <choice b>?"
            echo ":r answers y/n questions or decides between two choices."
            exit 0
        ;;
        # Our iterator only removes exactly one space.
        # Leading while command processing... so ignore it.
        '') ;;
        *)
            break
        ;;
    esac

    # Pop arg from message.
    # First branch handles the case where there isn't a trailing space.
    # Example with commas: 1,2,3,4 <-- last 4 would never be popped otherwise.
    if [[ "${msg#"$arg" }" == "$msg" ]]; then
        msg=
    else
        msg="${msg#"$arg" }"
    fi
done

# alternate yes or no form
case "$msg" in
    *' or '*) ;;
    *'? y/n') msg="${msg%' y/n'}"; YN=1 ;;
esac

# need better random source ???
declare -i RAND_MAX=32767 rand_val="$RANDOM"

reg='^(.*) or (.*)\?$' # decide
if [[ "$msg" =~ $reg ]]; then
    echo ":r $nick: ${BASH_REMATCH[(rand_val % 2)+1]}"
elif [[ "$msg" = *\? ]]; then
    if [[ "$YN" ]]; then
        (( RANDOM % 2 == 0 )) && y='yes'
        echo ":r $nick: ${y:-no}"
    else
        # modulo bias solution
        while (( rand_val >= ( RAND_MAX - ( RAND_MAX % 20 ) ) )); do
            rand_val="$RANDOM"
        done
        echo ":r $nick: ${responses[rand_val % 20]}"
    fi
else
    echo ":mn $nick Try asking a question (add a '?' to your question)."
fi
