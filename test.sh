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
    HIGHLIGHT="8ball.sh"
    PRIVMSG_DEFAULT_CMD='help'
    CMD_PREFIX=".,!"
    declare -gA COMMANDS
    COMMANDS=(
    ["8"]="8ball.sh" 
    ["8ball"]="8ball.sh" 
    ["define"]="define.sh"
    ["decide"]="8ball.sh" 
    ["duck"]="search.sh" 
    ["ddg"]="search.sh" 
    ["g"]="search.sh"
    ["help"]="help.sh"
    ["bots"]="bots.sh"
    ["source"]="bots.sh"
    ["v"]="vidme.sh"
    ["vid"]="vidme.sh"
    ["vidme"]="vidme.sh"
    #["w"]="weather.sh"
    ["owm"]="weather.sh"
    ["weather"]="weather.sh"
    ["wd"]="weatherdb.sh"
    ["location"]="weatherdb.sh"
    ["nws"]="nws.sh"
    ["nwsl"]="weatherdb.sh"
    ["nwsd"]="weatherdb.sh"
    ["npm"]="npm.sh"
    ["wiki"]="wikipedia.sh"
    ["reddit"]="subreddit.sh"
    ["sub"]="subreddit.sh"
    ["yt"]="youtube.sh"
    ["you"]="youtube.sh"
    ["youtube"]="youtube.sh"
    ["u"]="urbandict.sh"
    ["urban"]="urbandict.sh"
    ["bible"]="bible.sh"
    ["quran"]="bible.sh"
    ["fap"]="fap.sh"
    ["gay"]="fap.sh"
    ["straight"]="fap.sh"
    )
    REGEX=(
    'youtube.com|youtu.be' 'youtube.sh'
    '(https?)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]' 'pagetitle.sh'
    )
    IGNORE=(
    )
    ANTISPAM=yes
    ANTISPAM_TIMEOUT=30
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

cleanup() {
   echo 'ERROR :done testing' >&3
   rm ._TEST_IN ._TEST_OUT ._TEST_ERR
   exit 0
}
trap 'cleanup' SIGINT SIGTERM

# IPC
mkfifo ._TEST_IN
exec 3<> ._TEST_IN
mkfifo ._TEST_OUT
exec 4<> ._TEST_OUT
mkfifo ._TEST_ERR
exec 5<> ._TEST_ERR

./ircbot.sh -c "$0" <&3 >&4 2>debug.log &

# test nick cmd
read -r cmd nick <&4
if [ "$cmd" = 'NICK' ] && [ "$nick" = 'testnick' ]; then
    echo 'NICK COMMAND -> PASS'
else
    echo 'NICK COMMAND -> FAIL'
fi

# test user cmd
read -r cmd user mode unused realname <&4
if  [ "$cmd" = 'USER' ] &&
    [ "$user" = 'testnick' ] &&
    [ "$realname" = 'testnick' ] 
then
    echo 'USER COMMAND -> PASS'
else
    echo 'USER COMMAND -> FAIL'
fi

# send PING 
echo 'PING :hello' >&3
read -r pong string <&4
if [ "$pong" = 'PONG' ] && [ "$string" = ':hello' ]; then
    echo 'PONG -> PASS'
else
    echo 'PONG -> FAIL'
fi

# send post ident
echo ':doesnt@matter@user.host 004 doesntmatter :reg' >&3
read -r join chanstring <&4
if  [ "$join" = 'JOIN' ] &&
    [ "$chanstring" = '#chan1,#chan2' ]
then
    echo 'post_ident -> PASS'
else
    echo 'post_ident -> FAIL'
fi

cleanup
