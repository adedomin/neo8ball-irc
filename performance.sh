#!/usr/bin/env bash
rm ._PERF_TMP 2>/dev/null
CMDS=($'\001'"VERSION"$'\001' 'cmd')
for x in $(seq 1 "${1:-10000}"); do 
    line_uuid="$(< /proc/sys/kernel/random/uuid)"
    cmd="${CMDS[$(( RANDOM % 2 ))]}"
    echo ":$line_uuid!a@a PRIVMSG testnick :$cmd" >> ._PERF_TMP
done
time ./ircbot.sh -c ./test.sh \
    <  ._PERF_TMP \
    >  /dev/null \
    2> /dev/null
rm ._PERF_TMP 2>/dev/null
