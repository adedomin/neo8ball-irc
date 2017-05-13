#!/usr/bin/env bash
# shellcheck disable=2034

# if being sourced, act as config file.
if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
    NICK=testnick
    NICKSERV=testpass
    SERVER="localhost"
    CHANNELS=("#chan1" "#chan2")
    PORT="6667"
    TLS=
    temp_dir=/tmp
    READ_NOTICE=
    LOG_LEVEL=1
    LOG_STDOUT=
    LIB_PATH="$(dirname "$0")/lib/"
    HIGHLIGHT="testplugin.sh"
    CMD_PREFIX=".,!"
    declare -gA COMMANDS
    COMMANDS=(
    ['cmd']='bots.sh'
    )
    REGEX=(
    'regex' 'bots.sh'
    )
    IGNORE=(
    'ignorebot'
    )
    ANTISPAM=yes
    ANTISPAM_TIMEOUT=1
    ANTISPAM_COUNT=3
    HALFCLOSE_CHECK=3
    MOCK_CONN_TEST=yes
    return
fi


rm ._PERF_TMP 2>/dev/null
CMDS=($'\001'"VERSION"$'\001' 'cmd')
for x in $(seq 1 "${1:-10000}"); do 
    line_uuid="$(< /proc/sys/kernel/random/uuid)"
    cmd="${CMDS[$(( RANDOM % 2 ))]}"
    echo ":$line_uuid!a@a PRIVMSG testnick :$cmd" >> ._PERF_TMP
done
time ./ircbot.sh -c "$0" \
    <  ._PERF_TMP \
    >  /dev/null \
    2> /dev/null
rm ._PERF_TMP 2>/dev/null
