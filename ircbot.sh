#! /usr/bin/env bash
# Copyright 2016 prussian <generalunrest@airmail.cc>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

if [ -f ./config.sh ]; then
    . ./config.sh
else
    echo "NO CONFIG FILE FOUND"
    exit 1
fi

[ -d "$temp_dir/bash-ircbot" ] && rm -r "$temp_dir/bash-ircbot"
infile="$temp_dir/bash-ircbot/in"
outfile="$temp_dir/bash-ircbot/out"
mkdir "$temp_dir/bash-ircbot"
mkfifo "$infile"
mkfifo "$outfile"

quit_prg() {
    pkill -P $$
    exec 3>&-
    exec 4>&-
    rm -rf "$temp_dir/bash-ircbot"
    exit 0
}
trap 'quit_prg' SIGINT SIGHUP SIGTERM

if [ -z "$(which ncat 2>/dev/null)" ]; then
    echo "WARN: ncat not found, TLS will not be enabled" >&2
    BASH_TCP=a
fi

if [ -z "$NICK" ]; then
    echo "Nick was not specified" >&2
    usage
fi

send_msg() {
    printf "%s\r\n" "$*" >&3
}

if [ -n "$WEB_ROOT" ]; then
    if ! [ -d "$WEB_ROOT" ]; then
        mkdir "$WEB_ROOT" || \
            echo "failed to create web root" >&2 && \
            exit 1
    fi
    pushd "$WEB_ROOT" >/dev/null
    python2 -m SimpleHTTPServer "$WEB_PORT" >/dev/null 2>/dev/null </dev/null &
    popd >/dev/null
fi

[ -n "$TLS" ] && TLS="--ssl"
if [ -z "$BASH_TCP" ]; then
    exec 3<> "$infile"
    exec 4<> "$outfile"
    ncat $SERVER $PORT $TLS <&3 >&4 &
else
    infile="/dev/tcp/${SERVER}/${PORT}"
    exec 3<> "$infile"
    exec 4<&3
fi

send_cmd() {
    while read -r cmd arg other; do

        #echo "$cmd $arg $other"

        case $cmd in
            :j|:join)
                send_msg "JOIN $arg"
                ;;
            :l|:leave)
                send_msg "PART $arg :$other"
                ;;
            :m|:message)
                send_msg "PRIVMSG $arg :$other"
                ;;
            :mn|:notice)
                send_msg "NOTICE $arg :$other"
                ;;
            :w|:web)
                send_msg "PRIVMSG $arg :$DOMAIN/$other"
                ;;
            :n|:nick)
                send_msg "NICK $arg"
                ;;
            :q|:quit)
                send_msg "QUIT :$arg $other"
                kill -TERM $$
                ;;
            :r|:raw)
                send_msg "$arg $other"
                ;;
            *)
                ;;
        esac
    done
}

# $1: channel
# $2: datetime
# $3: user
# $4: msg
handle_privmsg() {
    if [ "$NICK" = "$1" ]; then
        if [[ "$message" =~ "VERSION" ]]; then
            echo -e ":mn $3 \001VERSION bash-ircbot: v0.0.1-ALPHA\001"
            return
        fi
        [ -x "$PRIVATE" ] || return
        $PRIVATE "$3" "$2" "$3" "$4" "$WEB_ROOT"
        return
    fi

    local highlight="$NICK.? (.*)"
    if [[ "$4" =~ $highlight ]]; then
        [ -x "$HIGHLIGHT" ] || return
        $HIGHLIGHT "$1" "$2" "$3" "${BASH_REMATCH[1]}" "$WEB_ROOT"
        return
    fi

    local comm
    local msg
    read -r comm msg <<< "$4"
    for cmd in "${!COMMANDS[@]}"; do
        if [[ "$comm" =~ [${CMD_PREFIX}]${cmd} ]]; then
            [ -x "${COMMANDS[$cmd]}" ] || return
            ${COMMANDS[$cmd]} "$1" "$2" "$3" "$msg" "$WEB_ROOT"
            return
        fi
    done

    for reg in "${!REGEX[@]}"; do
        if [[ "$4" =~ $reg ]]; then
            [ -x "${REGEX[$reg]}" ] || echo "NOOP"
            ${REGEX[$reg]} "$1" "$2" "$3" "$4" "$WEB_ROOT"
            return
        fi
    done

    echo "NOOP"
}

send_msg "NICK $NICK"
send_msg "USER $NICK +i * :$NICK"
# join chans
for channel in ${CHANNELS[*]}; do
    send_cmd <<< ":j $channel"
done

while read -r user command channel message; do
    user=$(sed 's/^:\([^!]*\).*/\1/' <<< "$user")
    datetime=$(date +"%Y-%m-%d %H:%M:%S")
    message=${message:1}
    # if ping request
    if [ "$user" = "PING" ]; then
        send_msg "PONG $command"
        continue
    fi

    [ "$user" = "$NICK" ] && continue
#    echo "$channel $user $datetime $message"
    case $command in
        PRIVMSG)
            handle_privmsg "$channel" "$datetime" "$user" "$message" | send_cmd
        ;;
        NOTICE)
            [ -z "$READ_NOTICE" ] && continue
            handle_privmsg "$channel" "$datetime" "$user" "$message" | send_cmd
        ;;
        JOIN)
            [ -z "$JOINING" ] && continue
            [ -x "$JOINING" ] || continue
            $JOINING "$channel" "$datetime" "$user" "$message" | send_cmd
        ;;
    esac
done <&4
