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
    LOG_STDOUT=y
    LIB_PATH="$(dirname "$0")/lib/"
    HIGHLIGHT=""
    CMD_PREFIX=".,!"
    declare -gA COMMANDS
    COMMANDS=(
    )
    REGEX=(
    )
    IGNORE=(
    'ignorebot'
    )
    GATEWAY=(
    'gateway'
    )
    ANTISPAM=yes
    ANTISPAM_TIMEOUT=1
    ANTISPAM_COUNT=3
    HALFCLOSE_CHECK=3
    MOCK_CONN_TEST=yes
    return
fi

IFS+=$'\r' # remove carriage returns from read
EXIT_CODE=0
RESTORE=$'\033[0m'
FAIL='['$'\033[00;31m'"FAIL${RESTORE}]"
PASS='['$'\033[00;32m'"PASS${RESTORE}]"
PAD='      '

fail() {
    echo "$FAIL $1"
    [ -n "$2" ] && {
        echo "$PAD Expected: $2"
    }
    EXIT_CODE=1
}

pass() {
    echo "$PASS $*"
}

cleanup() {
    echo 'ERROR :done testing' >&"${COPROC[1]}"
    echo '[****] Waiting on bot to exit'
    ( sleep 3s && fail 'ERROR COMMAND'; kill -TERM $$ ) &
    sleep_pid=$!
    wait "$COPROC_PID"
    kill -PIPE "$sleep_pid"
    pass 'ERROR COMMAND'
    exit "$EXIT_CODE"
}
trap 'cleanup' SIGINT

coproc ./ircbot.sh -c "$0" 2>debug.log

# test nick cmd
read -t 1 -u "${COPROC[0]}" -r cmd nick
if [ "$cmd" = 'NICK' ] && [ "$nick" = 'testnick' ]; then
    pass 'NICK COMMAND'
else
    fail 'NICK COMMAND' \
        "$cmd == NICK && $nick == testnick"
fi

# test user cmd
read -t 1 -u "${COPROC[0]}" -r cmd user mode unused realname
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
echo 'PING :hello' >&"${COPROC[1]}"
read -t 1 -u "${COPROC[0]}" -r pong string
if [ "$pong" = 'PONG' ] && [ "$string" = ':hello' ]; then
    pass 'PING/PONG COMMAND'
else
    fail 'PING/PONG COMMAND' \
        "$pong == PONG && $string == :hello"
fi

# send overly complex PING
echo 'PING :hello, this is  a    multiword ping' >&"${COPROC[1]}"
read -t 1 -u "${COPROC[0]}" -r pong string
if [ "$string" = ':hello, this is  a    multiword ping'$'\r' ]; then
    pass 'MULTIWORD PING/PONG COMMAND'
else
    fail 'MULTIWORD PING/PONG COMMAND' \
        "${string%$'\r'} == ':hello, this is  a    multiword ping'"
fi

# send post ident
echo ':doesnt@matter@user.host 004 doesntmatter :reg' >&"${COPROC[1]}"
read -t 1 -u "${COPROC[0]}" -r join chanstring
if  [ "$join" = 'JOIN' ] &&
    [ "$chanstring" = '#chan1,#chan2' ]
then
    pass 'post_ident function'
else
    fail 'post_ident function' \
        "$join == JOIN && $chanstring == #chan1,#chan2"
fi
# test that the bot attempted to identify for its nick
read -t 1 -u "${COPROC[0]}" -r cmd ident pass
if [ "$cmd" = 'NICKSERV' ] &&
   [ "$ident" = 'IDENTIFY' ] &&
   [ "$pass" = 'testpass' ]; then
    pass 'nickserv identify'
else
    fail 'nickserv identify' \
        "$cmd == NICKSERV && $ident == IDENTIFY && $pass == testpass"
fi

# test nick change feature p.1
# initial nick test
echo ':testbot __DEBUG neo8ball :nickname' >&"${COPROC[1]}"
read -t 1 -u "${COPROC[0]}" -r nick
if [ "$nick" = 'testnick' ]; then
    pass "nick variable 1"
else
    fail "nick variable 1" \
        "$nick == testnick"
fi

# notify the user the nick is in use
echo ':testbot 433 neo8ball :name in use' >&"${COPROC[1]}"
read -t 1 -u "${COPROC[0]}" -r cmd nick
if [ "$cmd" = 'NICK' ] && [ "$nick" = 'testnick_' ]; then
    pass '433 COMMAND (nick conflict)'
else
    fail '433 COMMAND (nick conflict)' \
        "$cmd == NICK && $nick == testnick_"
fi

# verify nick variable is what it reported
echo ':testbot __DEBUG neo8ball :nickname' >&"${COPROC[1]}"
read -t 1 -u "${COPROC[0]}" -r nick
if [ "$nick" = 'testnick_' ]; then
    pass "nick variable 2"
else
    fail "nick variable 2" \
        "$nick = testnick_"
fi

# channel joining
echo ':testnick_!blah@blah JOIN :#chan1 ' >&"${COPROC[1]}"
echo ':testnick_!blah@blah JOIN :#chan2 ' >&"${COPROC[1]}"
echo ':testbot __DEBUG neo8ball :channels' >&"${COPROC[1]}"
read -t 1 -u "${COPROC[0]}" -r channel
if [ "$channel" = '#chan1 #chan2' ]; then
    pass "JOIN test"
else
    fail 'JOIN test' \
        "$channel == '#chan1 #chan2'"
fi

# channel PART test
echo ':testnick_!blah@blah PART #chan2 :bye' >&"${COPROC[1]}"
echo ':testbot __DEBUG neo8ball :channels' >&"${COPROC[1]}"
read -t 1 -u "${COPROC[0]}" -r channel
if [ "$channel" = '#chan1' ]; then
    pass 'PART test'
else
    fail 'PART test' \
        "$channel == #chan1"
fi

# channel KICK test
echo ':testserv KICK #chan1 testnick_ :test message' >&"${COPROC[1]}"
echo ':testbot __DEBUG neo8ball :channels' >&"${COPROC[1]}"
read -t 1 -u "${COPROC[0]}" -r channel
if [ "$channel" = '' ]; then
    pass 'KICK test'
else
    fail 'KICK test' \
        "$channel == ''"
fi

# test ctcp VERSION
echo -e ':testbot PRIVMSG testnick_ :\001VERSION\001' >&"${COPROC[1]}"
read -t 1 -u "${COPROC[0]}" -r cmd channel message
if [ "$cmd" = 'NOTICE' ] &&
   [ "$channel" = 'testbot' ] &&
   [[ "$message" =~ $'\001VERSION bash-ircbot' ]]
then
    pass 'CTCP VERSION'
else
    fail 'CTCP VERSION' \
        "$message =~ "$'\001VERSION bash-ircbot'
fi

# message parsing tests
# test nickname
echo ':some!nick!lahblah!test@hostname __DEBUG #channel :nickparse' >&"${COPROC[1]}"
read -t 1 -u "${COPROC[0]}" -r msgnick
if [ "$msgnick" = 'some' ]; then
    pass 'IRC-LINE nick parse'
else
    fail 'IRC-LINE nick parse' \
        "$msgnick == some"
fi

# hostname parsing test
echo ':so@me!nick!lahblah!test@hostname __DEBUG #channel :hostparse' >&"${COPROC[1]}"
read -t 1 -u "${COPROC[0]}" -r msghost
if [ "$msghost" = 'hostname' ]; then
    pass 'IRC-LINE host parse'
else
    fail 'IRC-LINE host parse' \
        "$msghost = hostname"
fi

# chan parse
echo ':some!nick@hostname __DEBUG #chan :chanparse' >&"${COPROC[1]}"
read -t 1 -u "${COPROC[0]}" -r msgchan
if [ "$msgchan" = '#chan' ]; then
    pass 'IRC-LINE chan parse'
else
    fail 'IRC-LINE chan parse' \
        "$msgchan == #chan"
fi

# gateway user msg and username parse test
echo ':gateway!a@a __DEBUG #channel :<'$'\003''12,32actual_username'$'\003''> nickparse' >&"${COPROC[1]}"
read -t 1 -u "${COPROC[0]}" -r msgnick
if [ "$msgnick" = 'actual_username' ]; then
    pass 'GATEWAY trusted nick parse'
else
    fail 'GATEWAY trusted nick parse'
fi

# gateway host name parse test
echo ':gateway!a@a __DEBUG #channel :<'$'\003''12,32actual_username'$'\003''> hostparse' >&"${COPROC[1]}"
read -t 1 -u "${COPROC[0]}" -r msghost
if [ "$msghost" = 'actual_username.trusted-gateway.a' ]; then
    pass 'GATEWAY trusted host parse'
else
    fail 'GATEWAY trusted host parse'
fi

# gateway fail parse
echo ':gateway2!a@a __DEBUG #channel :<actual_username> nickparse' >&"${COPROC[1]}"
read -t 1 -u "${COPROC[0]}" -r msgnick
if [ "$msgnick" == '<actual_username> nickparse' ]; then
    pass 'GATEWAY untrusted nick parse'
else
    fail 'GATEWAY untrusted nick parse'
fi


# ignore user test
echo -e ':ignorebot PRIVMSG testnick_ :\001VERSION\001' >&"${COPROC[1]}"
echo '[****] Waiting for ingore user test timeout'
read -t 1 -u "${COPROC[0]}" -r line
if [ -z "$line" ]; then  
    pass 'ignore nick test'
else
    fail 'ignore nick test'
fi

# antispam test
echo -e ':testbot2 PRIVMSG testnick_ :\001VERSION\001' >&"${COPROC[1]}"
read -t 1 -u "${COPROC[0]}" -r line
[ -z "$line" ] && aspam=1
echo -e ':testbot2 PRIVMSG testnick_ :\001VERSION\001' >&"${COPROC[1]}"
read -t 1 -u "${COPROC[0]}" -r line
[ -z "$line" ] && aspam=1
echo -e ':testbot2 PRIVMSG testnick_ :\001VERSION\001' >&"${COPROC[1]}"
read -t 1 -u "${COPROC[0]}" -r line
[ -z "$line" ] && aspam=1

# now test the bot properly ignores testbot2
echo -e ':testbot2 PRIVMSG testnick_ :\001VERSION\001' >&"${COPROC[1]}"
echo '[****] Waiting for antispam timeout'
read -t 1 -u "${COPROC[0]}" -r line
[ -n "$line" ] && aspam=1
echo -e ':testbot2 PRIVMSG testnick_ :\001VERSION\001' >&"${COPROC[1]}"
read -t 1 -u "${COPROC[0]}" -r line
if [ -n "$line" ] && [ -z "$aspam" ]; then
    pass 'antispam test'
else
    fail 'antispam test'
fi

# reload config test
# join some bs channels first to see if the bot parts them correctly
echo ':testnick_!blah@blah JOIN :#chan3' >&"${COPROC[1]}"
echo ':testnick_!blah@blah JOIN :#chan4' >&"${COPROC[1]}"
echo ':testbot __DEBUG neo8ball :channels' >&"${COPROC[1]}"
read -t 1 -u "${COPROC[0]}" -r channel
# should emit nick since current nick != config nick
kill -SIGHUP "$COPROC_PID"
read -t 1 -u "${COPROC[0]}" -r cmd nick
if [ "$cmd" = 'NICK' ] &&
   [ "$nick" = 'testnick' ]
then
    pass 'config reload 1 (nick change)'
else
    fail 'config reload 1 (nick change)'
fi

# should part all channels not in config
# should join channels that are in the config
# but are not joined to
for itr in {1,2}; do
    read -t 1 -u "${COPROC[0]}" -r cmd channel unused
    if [ "$cmd" = 'JOIN' ]; then
        if [ "$channel" != '#chan1,#chan2' ]
        then
            fail 'config reload 2 (channel part/join)' \
                "$channel == #chan1,#chan2"
            config_fail=2
            break
        fi
    elif [ "$cmd" = 'PART' ]; then
        if [ "$channel" != '#chan4,#chan3' ]
        then
            fail 'config reload 2 (channel part/join)' \
                "$channel == #chan4,#chan3"
            config_fail=2
            break
        fi
    else
        fail 'config reload 2 (channel part/join)' \
            "$cmd == JOIN || $cmd == PART"
        config_fail=2
        break
    fi
done
[ -z "$config_fail" ] && pass 'config reload 2 (channel part/join)'

# forced rename
echo ':testnick NICK :newnick' >&"${COPROC[1]}"
echo ':blah __DEBUG blah :nickname' >&"${COPROC[1]}"
read -t 1 -u "${COPROC[0]}" -r nick
if [ "$nick" = 'newnick' ]; then
    pass "NICK forced rename"
else
    fail "NICK forced rename" \
        "$nick == newnick"
fi

cleanup
