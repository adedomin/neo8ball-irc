#!/usr/bin/env bash
# shellcheck disable=2034
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

# if being sourced, act as config file. lol
if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
    NICK=testnick
    NICKSERV=testpass
    SERVER="irc.rizon.net"
    CHANNELS=("#chan1" "#chan2")
    PORT="6697"
    TLS=yes
    temp_dir=/tmp
    READ_NOTICE=
    LOG_LEVEL=1
    LOG_STDOUT=
    LIB_PATH="$(dirname "$0")/lib/"
    HIGHLIGHT="testplugin.sh"
    CMD_PREFIX=".,!"
    declare -gA COMMANDS
    COMMANDS=(
    ['cmd']='testplugin.sh'
    )
    REGEX=(
    'regex' 'testplugin.sh'
    )
    IGNORE=(
    'ignorebot'
    )
    ANTISPAM=yes
    ANTISPAM_TIMEOUT=1
    ANTISPAM_COUNT=3
    HALFCLOSE_CHECK=3
    export OWM_KEY="your owm key"
    export PERSIST_LOC="/tmp"
    export YOUTUBE_KEY="your youtube api key"
    export BIBLE_SOURCE="$(dirname "$0")/static/king-james.txt"
    export QURAN_SORUCE="$(dirname "$0")/static/quran-allah-ver.txt"
    URI_ENCODE() {
        curl -Gso /dev/null \
            -w '%{url_effective}' \
            --data-urlencode @- '' <<< "$1" |
        cut -c 3- |
        sed 's/%0A$//g'
    }
    export -f URI_ENCODE
    MOCK_CONN_TEST=yes
    return
fi

IFS+=$'\r' # remove carriage returns from read -t 1s
EXIT_CODE=0
RESTORE=$'\033[0m'
FAIL='['$'\033[00;31m'"FAIL${RESTORE}]"
PASS='['$'\033[00;32m'"PASS${RESTORE}]"

fail() {
    echo "$FAIL $*"
    EXIT_CODE=1
}

pass() {
    echo "$PASS $*"
}

cleanup() {
    echo 'ERROR :done testing' >&3
    rm ._TEST_IN ._TEST_OUT
    echo '[****] Waiting on bot to exit'
    ( sleep 3s && fail 'ERROR COMMAND'; kill -TERM $$ ) &
    sleep_pid=$!
    wait "$TEST_PROC"
    kill -PIPE "$sleep_pid"
    pass 'ERROR COMMAND'
    exit "$EXIT_CODE"
}
trap 'cleanup' SIGINT

# IPC
mkfifo ._TEST_IN
exec 3<> ._TEST_IN
mkfifo ._TEST_OUT
exec 4<> ._TEST_OUT

./ircbot.sh -c "$0" <&3 >&4 2>debug.log &
TEST_PROC=$!

# test nick cmd
read -t 1 -u 4 -r cmd nick
if [ "$cmd" = 'NICK' ] && [ "$nick" = 'testnick' ]; then
    pass 'NICK COMMAND'
else
    fail 'NICK COMMAND'
fi

# test user cmd
read -t 1 -u 4 -r cmd user mode unused realname
if  [ "$cmd" = 'USER' ] &&
    [ "$user" = 'testnick' ] &&
    [ "$mode" = '+i' ] &&
    [ "$unused" = '*' ] &&
    [ "$realname" = ':testnick' ] 
then
    pass 'USER COMMAND'
else
    fail 'USER COMMAND'
fi

# send PING 
echo 'PING :hello' >&3
read -t 1 -u 4 -r pong string
if [ "$pong" = 'PONG' ] && [ "$string" = ':hello' ]; then
    pass 'PING/PONG COMMAND'
else
    fail 'PING/PONG COMMAND'
fi

# send post ident
echo ':doesnt@matter@user.host 004 doesntmatter :reg' >&3
read -t 1 -u 4 -r join chanstring
if  [ "$join" = 'JOIN' ] &&
    [ "$chanstring" = '#chan1,#chan2' ]
then
    pass 'post_ident function'
else
    fail 'post_ident function'
fi
# test that the bot attempted to identify for its nick
read -t 1 -u 4 -r cmd ident pass
if [ "$cmd" = 'NICKSERV' ] &&
   [ "$ident" = 'IDENTIFY' ] &&
   [ "$pass" = 'testpass' ]; then
    pass 'nickserv identify'
else
    fail 'nickserv identify'
fi

# test nick change feature p.1
# initial nick test
echo ':testbot __DEBUG neo8ball :nickname' >&3
read -t 1 -u 4 -r nick
if [ "$nick" = 'testnick' ]; then
    pass "nick variable 1"
else
    fail "nick variable 1"
fi

# notify the user the nick is in use
echo ':testbot 433 neo8ball :name in use' >&3
read -t 1 -u 4 -r cmd nick
if [ "$cmd" = 'NICK' ] && [ "$nick" = 'testnick_' ]; then
    pass '433 COMMAND (nick conflict)'
else
    fail '433 COMMAND (nick conflict)'
fi

# verify nick variable is what it reported
echo ':testbot __DEBUG neo8ball :nickname' >&3
read -t 1 -u 4 -r nick
if [ "$nick" = 'testnick_' ]; then
    pass "nick variable 2"
else
    fail "nick variable 2"
fi

# channel joining
echo ':testnick_!blah@blah JOIN :#chan1 ' >&3
echo ':testnick_!blah@blah JOIN :#chan2 ' >&3
echo ':testbot __DEBUG neo8ball :channels' >&3
read -t 1 -u 4 -r channel
if [ "$channel" = '#chan1 #chan2' ]; then
    pass "JOIN test"
else
    fail 'JOIN test'
fi

# channel PART test
echo ':testnick_!blah@blah PART #chan2 :bye' >&3
echo ':testbot __DEBUG neo8ball :channels' >&3
read -t 1 -u 4 -r channel
if [ "$channel" = '#chan1' ]; then
    pass 'PART test'
else
    fail 'PART test'
fi

# channel KICK test
echo ':testserv KICK #chan1 testnick_ :test message' >&3
echo ':testbot __DEBUG neo8ball :channels' >&3
read -t 1 -u 4 -r channel
if [ "$channel" = '' ]; then
    pass 'KICK test'
else
    fail 'KICK test'
fi

# test ctcp VERSION
echo -e ':testbot PRIVMSG testnick_ :\001VERSION\001' >&3
read -t 1 -u 4 -r cmd channel message
if [ "$cmd" = 'NOTICE' ] &&
   [ "$channel" = 'testbot' ] &&
   [[ "$message" =~ $'\001VERSION bash-ircbot' ]]
then
    pass 'CTCP VERSION'
else
    fail 'CTCP VERSION'
fi

# ignore user test
echo -e ':ignorebot PRIVMSG testnick_ :\001VERSION\001' >&3
echo '[****] Waiting for ingore user test timeout'
read -t 0.2 -u 4 -r line
if [ -z "$line" ]; then  
    pass 'ignore nick test'
else
    fail 'ignore nick test'
fi

# antispam test
echo -e ':testbot2 PRIVMSG testnick_ :\001VERSION\001' >&3
read -t 1 -u 4 -r line
[ -z "$line" ] && fail 'antispam test'
echo -e ':testbot2 PRIVMSG testnick_ :\001VERSION\001' >&3
read -t 1 -u 4 -r line
[ -z "$line" ] && fail 'antispam test'
echo -e ':testbot2 PRIVMSG testnick_ :\001VERSION\001' >&3
read -t 1 -u 4 -r line
[ -z "$line" ] && fail 'antispam test'

# now test the bot properly ignores testbot2
echo -e ':testbot2 PRIVMSG testnick_ :\001VERSION\001' >&3
echo '[****] Waiting for antispam timeout'
read -t 2 -u 4 -r line
[ -n "$line" ] && fail 'antispam test'
echo -e ':testbot2 PRIVMSG testnick_ :\001VERSION\001' >&3
read -t 1 -u 4 -r line
if [ -n "$line" ]; then
    pass 'antispam test'
else
    fail 'antispam test'
fi

cleanup
