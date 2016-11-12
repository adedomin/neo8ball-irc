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

usage() {
    echo "usage: $0 [-c config]"
    echo "       -c --config - a config file"
    echo ""
    echo "by default, if empty, the script assumes all the information can be found in the same directory as the script"
    exit 1
}

die() {
    echo "$1" >&2
    exit 1
}

while [ $# -gt 0 ]; do
    case "$1" in
        -c|--config)
            CONFIG_PATH="$2"
            shift
        ;;
        -h|--help)
            usage
        ;;
    esac
done

if [ -z "$CONFIG_PATH" ]; then
    CONFIG_PATH="$(dirname "$0")/config.sh"
fi

if [ -f "$CONFIG_PATH" ]; then
    . "$CONFIG_PATH"
else
    echo "NO CONFIG FILE FOUND"
    usage
fi

[ -d "$temp_dir/bash-ircbot" ] && rm -r "$temp_dir/bash-ircbot"
infile="$temp_dir/bash-ircbot/in"
outfile="$temp_dir/bash-ircbot/out"
mkdir "$temp_dir/bash-ircbot" || \
    die "failed to make temp directory, check your config"
mkfifo "$infile" || \
    die "couldn't make named pipe"
mkfifo "$outfile" || \
    die "couldn't make named pipe"

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

[ -n "$TLS" ] && TLS="--ssl"
if [ -z "$BASH_TCP" ]; then
    exec 3<> "$infile" || \
        die "unknown failure mapping named pipe to fd"
    exec 4<> "$outfile" || \
        die "unknown failure mapping named pipe to fd"
    ( ncat $SERVER $PORT $TLS <&3 >&4
      kill -TERM $$ ) &
else
    infile="/dev/tcp/${SERVER}/${PORT}"
    exec 3<> "$infile" || \
        die "Cannot connect to $SERVER on port $PORT"
    exec 4<&3 || \
        die "unknown failure mapping named pipe to fd"
fi

send_msg() {
    printf "%s\r\n" "$*" >&3
}

send_cmd() {
    while read -r cmd arg other; do

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
        [ -x "$LIB_PATH/$PRIVATE" ] || return
        $LIB_PATH/$PRIVATE \
            "$3" "$2" "$3" "$4"
        return
    fi

    local highlight="$NICK.? (.*)"
    if [[ "$4" =~ $highlight ]]; then
        [ -x "$LIB_PATH/$HIGHLIGHT" ] || return
        $LIB_PATH/$HIGHLIGHT \
            "$1" "$2" "$3" "${BASH_REMATCH[1]}"
        return
    fi

    for cmd in "${!COMMANDS[@]}"; do
        local reg="^[${CMD_PREFIX}]${cmd}\\b(.*)"
        if [[ "$4" =~ $reg ]]; then
            [ -x "$LIB_PATH/${COMMANDS[$cmd]}" ] || return
            $LIB_PATH/${COMMANDS[$cmd]} \
                "$1" "$2" "$3" "${BASH_REMATCH[1]}"
            return
        fi
    done

    for reg in "${!REGEX[@]}"; do
        if [[ "$4" =~ $reg ]]; then
            [ -x "$LIB_PATH/${REGEX[$reg]}" ] || return
            $LIB_PATH/${REGEX[$reg]} \
                "$1" "$2" "$3" "$4"
            return
        fi
    done
}

# start communication
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
            [ -z "$READ_NOTICE" ] || \
            handle_privmsg "$channel" "$datetime" "$user" "$message" | send_cmd
        ;;
        JOIN)
            [ -x "$JOINING" ] && \
            $JOINING "$channel" "$datetime" "$user" "$message" | send_cmd
        ;;
    esac
done <&4
