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
    INVITE_FILE=./.invites-test-file
    TRACK_CHAN_MODE=1
    return
fi

IFS+=$'\r'
EXIT_CODE=0
PAD='       '

format_expected() {
REPLY="
${PAD}Expected: $1
${PAD}Received: $2"
}

fail() {
    printf '[\033[00;31mFAIL\033[0m] %s' "$1"
    if (( $# == 3 )); then
        format_expected "$2" "$3"
        printf "%s\n" "$REPLY"
    else
        printf '\n'
    fi
    EXIT_CODE=1
}

pass() {
    printf '[\033[00;32mPASS\033[0m] %s\n' "$1"
}

info() {
    printf '[****] %s\n' "$1"
}

# Write the given strings to the bot to process.
write_to() {
    printf '%s\n' "$*" >&"${COPROC[1]}"
}

# Read from bot, arguments become variables
# if no variables passed, check REPLY
read_from() {
    read -t 1 -u "${COPROC[0]}" -r "$@"
}

cleanup() {
    write_to 'ERROR :done testing'
    info 'Waiting on bot to exit.'
    ( sleep 3s && fail 'ERROR COMMAND'; kill -TERM $$ ) &
    sleep_pid=$!
    wait "$COPROC_PID"
    kill -PIPE "$sleep_pid"
    pass 'ERROR COMMAND'
    rm -f -- .invites-test-file
    exit "$EXIT_CODE"
}
trap 'cleanup' SIGINT

coproc ./ircbot.sh -c "$0" 2>debug.log

# test IRCv3 cap negotiation
# note that TRACK_CHAN_MODE expects multi-prefix
ircv3_negotiate() {
    read_from cap req multi
    [[  "$cap"   == 'CAP' &&
        "$req"   == 'REQ' &&
        "$multi" == ':multi-prefix' ]]
}
if ircv3_negotiate; then
    pass 'IRCv3 CAP Negotiation. (:multi-prefix)'
else
    fail 'IRCv3 CAP Negotiation. (:multi-prefix)' \
        "CAP REQ :multi-prefix" \
        "$cap $req $multi"
fi

test_nick_cmd() {
    read_from cmd nick
    [[  "$cmd" = 'NICK' &&
        "$nick" = 'testnick' ]]
}
if test_nick_cmd; then
    pass 'NICK COMMAND'
else
    fail 'NICK COMMAND' \
        "cmd = NICK && nick = testnick" \
        "cmd = $cmd && nick = $nick"
fi

test_user_cmd() {
    read_from cmd user mode unused realname
    [[  "$cmd"      == 'USER' &&
        "$user"     == 'testnick' &&
        "$mode"     == '+i' &&
        "$unused"   == '*' &&
        "$realname" == ':testnick' ]]
}
if test_user_cmd; then
    pass 'USER COMMAND'
else
    fail 'USER COMMAND' \
        'cmd = USER && user = testnick && mode = +i && unused = * && realname = :testnick' \
        "cmd = $cmd && user = $user && mode = $mode && unused = $unused && realname = $realname"
fi

# test CAP ACK and expect END
ircv3_negotiate_ack_end() {
    write_to ':server CAP * ACK :multi-prefix'
    read_from cap end
    [[  "$cap" == 'CAP' &&
        "$end" == 'END' ]]
}
if ircv3_negotiate_ack_end; then
    pass 'CAP ACK/END'
else
    fail 'CAP ACK/END' \
         'CAP END' \
         "$cap $end"
fi

send_ping() {
    write_to 'PING :hello'
    read_from pong string
    [[  "$pong"   == 'PONG' &&
        "$string" == ':hello' ]]
}
if send_ping; then
    pass 'PING/PONG COMMAND'
else
    fail 'PING/PONG COMMAND' \
        "PONG :hello" \
        "$pong $string"
fi

send_complex_ping() {
    write_to 'PING :hello, this is  a    multiword ping'
    read_from pong string
    [[ "$string" == ':hello, this is  a    multiword ping'$'\r' ]]
}
if send_complex_ping; then
    pass 'MULTIWORD PING/PONG COMMAND'
else
    fail 'MULTIWORD PING/PONG COMMAND' \
        ':hello, this is  a    multiword ping' \
        "${string%$'\r'}"
fi

# send_post_ident
if {
    write_to ':doesnt@matter@user.host 004 doesntmatter :reg'
    read_from join chanstring
    [[  "$join"       == 'JOIN' &&
        "$chanstring" == '#chan1,#chan2' ]]
} then
    pass 'post_ident function'
else
    fail 'post_ident function' \
        'JOIN #chan1,#chan2' \
        "$join $chanstring"
fi
# send_nickserv_ident
if {
    read_from cmd ident pass
    [[   "$cmd"   == 'NICKSERV' &&
         "$ident" == 'IDENTIFY'  &&
         "$pass"  == 'testpass' ]]
} then
    pass 'nickserv identify'
else
    fail 'nickserv identify' \
        'NICKSERV IDENTIFY testpass' \
        "$cmd $ident testpass"
fi

# test nick change feature p.1
# initial nick test
nick_change() {
    write_to ':testbot __DEBUG neo8ball :nickname' >&"${COPROC[1]}"
    read_from nick
    [[ "$nick" = 'testnick' ]]
}
if nick_change; then
    pass "nick variable 1"
else
    fail "nick variable 1" \
        'testnick' \
        "$nick"
fi

# notify the user the nick is in use
nick_conflict() {
    write_to ':testbot 433 neo8ball :name in use'
    read_from cmd nick
    [[  "$cmd"  == 'NICK' &&
        "$nick" == 'testnick_' ]]
}
if nick_conflict; then
    pass '433 COMMAND (nick conflict)'
else
    fail '433 COMMAND (nick conflict)' \
        'NICK testnick_' \
        "$cmd $nick"
fi

# verify nick variable is what it reported
get_nick() {
    write_to ':testbot __DEBUG neo8ball :nickname'
    read_from nick
}
get_nick
if [[ "$nick" == 'testnick_' ]]; then
    pass "nick variable 2"
else
    fail "nick variable 2" \
        'testnick_' \
        "$nick"
fi

# $1 - join with separator
# $* - list to join
join_str() {
    local IFS="$1"
    shift
    printf -v REPLY '%s' "$*"
}

# $1 - our username
# $2 - channel to join
join_channel() {
    local uname="$1"
    shift
    for arg; do
        write_to ":$uname JOIN :$arg"
    done
}

get_channels() {
    write_to ':testbot __DEBUG neo8ball :channels'
    read_from channel
}

test_join_command() {
    get_channels
    if [[ "$channel" != '' ]]; then
        format_expected '' "$channel"
        REPLY="expected to not be joined to channels$REPLY"
        return 1
    fi

    local expected_channels=('#chan1' '#chan2')
    join_channel 'testnick_!blah@blah' "${expected_channels[@]}"
    get_channels
    join_str ' ' "${expected_channels[@]}"
    local expected="$REPLY"
    if [[ "$channel" != "$expected" ]]; then
        format_expected "$expected" "$channel"
        REPLY="expected to be joined to channels$REPLY"
        return 1
    fi

    return 0
}
if test_join_command; then
    pass 'JOIN command'
else
    fail "JOIN command - $REPLY"
fi

if {
    write_to ":testnick_!blah@blah PART #chan2 :bye"
    get_channels
    [[ "$channel" == '#chan1' ]]
} then
    pass 'PART command'
else
    fail 'PART command' \
        '#chan1' \
        "$channel"
fi

# channel KICK test
if {
    write_to ':testserv KICK #chan1 testnick_ :test message'
    get_channels
    [[ "$channel" = '' ]]
} then
    pass 'KICK test'
else
    fail 'KICK test' \
        "$channel == ''"
fi

# test ctcp VERSION
if {
    write_to $':testbot PRIVMSG testnick_ :\001VERSION\001'
    read_from cmd channel message
    [[  "$cmd"     == 'NOTICE' &&
        "$channel" == 'testbot' &&
        "$message" =~ $'\001VERSION neo8ball' ]]
} then
    pass 'CTCP VERSION'
else
    fail 'CTCP VERSION' \
        "NOTICE testbot VERSION neo8ball ...rest" \
        "$cmd $channel $message"
fi

get_nickname() {
    write_to ":$1 __DEBUG #channel :${2:+"$2 "}nickparse"
    read_from msgnick
}

# message parsing tests
# test nickname
if {
    get_nickname 'some!nick!lahblah!test@hostname'
    [[ "$msgnick" == 'some' ]]
} then
    pass 'IRC-LINE nick parse'
else
    fail 'IRC-LINE nick parse' \
        "some" \
        "$msgnick"
fi

get_hostname() {
    write_to ":$1 __DEBUG #channel :${2:+"$2 "}hostparse"
    read_from msghost
}

# hostname parsing test
if {
    get_hostname 'so@me!nick!lahblah!test@hostname'
    [[ "$msghost" == 'hostname' ]]
} then
    pass 'IRC-LINE host parse'
else
    fail 'IRC-LINE host parse' \
        'hostname' \
        "$msghost"
fi

# chan parse
if {
    write_to ':some!nick@hostname __DEBUG #chan :chanparse'
    read_from msgchan
    [[ "$msgchan" = '#chan' ]]
} then
    pass 'IRC-LINE chan parse'
else
    fail 'IRC-LINE chan parse' \
        '$chan' \
        "$msgchan"
fi

# gateway user msg and username parse test
if {
    get_nickname 'gateway!a@a' '<'$'\003''12,32actual_username'$'\003''>'
    [[ "$msgnick" = 'actual_username' ]]
} then
    pass 'GATEWAY trusted nick parse'
else
    fail 'GATEWAY trusted nick parse' \
        "actual_username" \
        "$msgnick"
fi

# gateway host name parse test
if {
    get_hostname 'gateway!a@a' '<'$'\003''12,32actual_username'$'\003''>'
    [[ "$msghost" = 'actual_username.trusted-gateway.a' ]]
} then
    pass 'GATEWAY trusted host parse'
else
    fail 'GATEWAY trusted host parse' \
        'actual_username.trusted-gateway.a' \
        "$msghost"
fi

# gateway fail parse
if {
    get_nickname 'gateway2!a@a' '<actual_username>'
    [[ "$msgnick" == '<actual_username> nickparse' ]]
} then
    pass 'GATEWAY untrusted nick parse'
else
    fail 'GATEWAY untrusted nick parse' \
        "<actual_username> nickparse" \
        "$msgnick"
fi

# 353 (with IRCv3 multi-prefix) response test
{
    echo ':server 353 testnick_ = #chan :@userx &%+usery +userz noprefix'
    echo ':server __DEBUG #chan chanmode :usery'
} >&"${COPROC[1]}"
read -t 1 -u "${COPROC[0]}" -r msgmode
if [ "$msgmode" = 'a' ]; then
    pass 'CHANNEL MODE PARSE'
else
    fail 'CHANNEL MODE PARSE' \
         'Expected: a; Got: '"$msgmode"
fi

# MAKE SURE noprefix works.
echo ':server __DEBUG #chan chanmode :noprefix' >&"${COPROC[1]}"
read -t 1 -u "${COPROC[0]}" -r msgmode
if [ "$msgmode" = '' ]; then
    pass 'CHANNEL MODE PARSE (none)'
else
    fail 'CHANNEL MODE PARSE (none)' \
         'Expected: <NOTHING>; Got: '"$msgmode"
fi

# MODE parsing
# We have set some user channel modes using NAMES reply
# lets edit some and make sure the bot is properly handling MODEs
{
    echo ":whocares MODE #chan +mb -a *!*@banned.user usery +o userz +il 45"
    echo ":whocares __DEBUG #chan chanmode :usery"
} >&"${COPROC[1]}"
read -t 1 -u "${COPROC[0]}" -r msgmode
if [ "$msgmode" = 'h' ]; then
    pass 'MODE COMMAND PARSE (remove)'
else
    fail 'MODE COMMAND PARSE (remove)' \
         'Expected: h; Got: '"$msgmode"
fi

echo ":whocares __DEBUG #chan chanmode :userz" >&"${COPROC[1]}"
read -t 1 -u "${COPROC[0]}" -r msgmode
if [ "$msgmode" = 'o' ]; then
    pass 'MODE COMMAND PARSE (add)'
else
    fail 'MODE COMMAND PARSE (add)' \
         'Expected: o; Got: '"$msgmode"
fi

ignore_user_test() {
    printf ':ignorebot PRIVMSG testnick_ :\001VERSION\001\n' >&"${COPROC[1]}"
    echo '[****] Waiting for ingore user test timeout'
    read -t 1 -u "${COPROC[0]}" -r line
    [[ -z "$line" ]]
}

if ignore_user_test; then
    pass 'ignore user test'
else
    fail "ignore user test"
fi

antispam_test() {
    local i
    for (( i=1; i <= 3; ++i )); do
        printf ':testbot2 PRIVMSG testnick_ :\001VERSION\001\n' >&"${COPROC[1]}"
        read -t 1 -u "${COPROC[0]}" -r line
        [[ -z "$line" ]] && {
            REPLY='antispam triggered too early. ('"$i"' <= 3)'
            return 1
        }
    done

    printf ':testbot2 PRIVMSG testnick_ :\001VERSION\001\n' >&"${COPROC[1]}"
    echo '[****] Waiting for antispam timeout'
    read -t 1 -u "${COPROC[0]}" -r line
    if [[ -n "$line" ]]; then
        REPLY='antispam did not trigger after 3 consecutive messages.'
        return 1
    fi

    printf ':testbot2 PRIVMSG testnick_ :\001VERSION\001\n' >&"${COPROC[1]}"
    read -t 1 -u "${COPROC[0]}" -r line
    if [[ -z "$line" ]]; then
        REPLY='after 1 second, antispam did not deactivate.'
        return 1
    fi

    printf ':testbot2 PRIVMSG testnick_ :\001VERSION\001\n' >&"${COPROC[1]}"
    echo '[****] Waiting for antispam timeout'
    read -t 1 -u "${COPROC[0]}" -r line
    if [[ -n "$line" ]]; then
        REPLY='antispam gave us too many message allowances.'
        return 1
    fi

    return 0
}

if antispam_test; then
    pass 'antispam test'
else
    fail "antispam test - $REPLY"
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

# test massive join feature
# feature only impacts config reload and post-ident
# test depends on pwgen or like binary to generate gibberish
pwgen 16 128 \
| sed 's/^/#/; :start; N; $ { s/\n/,#/g; b; }; b start'\
> ./.invites-test-file
expected_total_join=",$(< ./.invites-test-file)"
actual_total_join=
kill -SIGHUP "$COPROC_PID"
while read -t 1 -u "${COPROC[0]}" -r cmd channel unused; do
    if [[ "$cmd" == 'JOIN' ]]; then
        chan_len="$(printf '%s' "$channel" | wc -c)"
        (( chan_len > 500 )) && {
            actual_total_join=
            break
        }
        actual_total_join+=",$channel"
        [[ "$actual_total_join" == "$expected_total_join" ]] && break
    fi
done
if [[ "$actual_total_join" == "$expected_total_join" ]]; then
    pass '>500 char line channel join'

else
    fail '>500 char line channel join'
fi

# test massive part now
rm -f .invites-test-file
expected_total_part="$expected_total_join"
actual_total_part=
kill -SIGHUP "$COPROC_PID"
while read -t 1 -u "${COPROC[0]}" -r cmd channel unused; do
    if [[ "$cmd" == 'PART' ]]; then
        chan_len="$(printf '%s' "$channel" | wc -c)"
        (( chan_len > 500 )) && {
            actual_total_part=
            break
        }
        actual_total_part+=",$channel"
        [[ "$actual_total_part" == "$expected_total_part" ]] && break
    fi
done
if [[ "$actual_total_part" == "$expected_total_part" ]]; then
    pass '>500 line channel part'

else
    fail '>500 line channel part'
fi

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
