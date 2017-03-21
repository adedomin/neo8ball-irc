#!/usr/bin/env bash
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
VERSION="bash-ircbot: v1.4.6"

usage() {
    echo "usage: $0 [-c config]"
    echo "       -c --config - a config file"
    echo ""
    echo "by default, if empty, the script assumes all the information can be found in the same directory as the script"
    exit 1
}

die() {
    echo "*** CRITICAL *** $1" >&2
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
        *)
            usage
        ;;
    esac
    shift
done

########
# INIT #
########

# find default configuration path
# location script's directory
if [ -z "$CONFIG_PATH" ]; then
    CONFIG_PATH="$(dirname "$0")/config.sh"
fi

# load configuration
if [ -f "$CONFIG_PATH" ]; then
    # shellcheck disable=SC1090
    . "$CONFIG_PATH"
else
    echo "*** CRITICAL *** no configuration"
    usage
fi

# set up IPC mechanisms
# named pipes to connect ncat to message loop
# shellcheck disable=SC2154
[ -d "$temp_dir/bash-ircbot" ] && rm -r "$temp_dir/bash-ircbot"
infile="$temp_dir/bash-ircbot/in"
outfile="$temp_dir/bash-ircbot/out"
mkdir "$temp_dir/bash-ircbot" ||
    die "failed to make temp directory, check your config"
mkfifo "$infile" ||
    die "couldn't make named pipe"
mkfifo "$outfile" ||
    die "couldn't make named pipe"
# if you wnt to prevent blatant command spam
# by certain users
# shellcheck disable=SC2153
if [ -n "$ANTISPAM" ]; then
    antispam="$temp_dir/bash-ircbot/antispam"
    touch "$antispam" ||
        die "couldn't make file"
fi

# handler to terminate bot
# can not trap SIGKILL
# make sure you kill with SIGTERM or SIGINT
quit_prg() {
    pkill -P $$
    exec 3>&-
    exec 4>&-
    exec 5>&-
    rm -rf "$temp_dir/bash-ircbot"
    exit 0
}
trap 'quit_prg' SIGINT SIGTERM

# helper for channel config reload
# determine if chan is in channel list
contains_chan() {
  for chan in "${@:2}"; do 
      [ "$chan" = "$1" ] && return 0
  done
  return 1
}

# handle configuration reloading
# faster than restarting
# will: change nick (if applicable)
#       reauth with nickserv
#       join/part new or removed channels
#       reload all other variables, like COMMANDS, etc
reload_config() {
    local _NICK="$NICK"
    # shellcheck disable=SC2153
    local _NICKSERV="$NICKSERV"
    local _CHANNELS=("${CHANNELS[@]}")
    # shellcheck disable=SC1090
    . "$CONFIG_PATH"
    # NICK changed
    if [ "$NICK" != "$_NICK" ]; then
        send_msg "NICK $NICK"
    fi
    # pass change for nickserv
    if [ "$NICKSERV" != "$_NICKSERV" ]; then
        printf "%s\r\n" "PRIVMSG NickServ :IDENTIFY $NICKSERV" >&3
    fi
    
    # join or part channels based on new channel list
    uniq_chan_list="$(printf '%s\n' "${_CHANNELS[@]}" "${CHANNELS[@]}" | sort | uniq -u)"
    for uniq_chan in $uniq_chan_list; do
        if contains_chan "$uniq_chan" "${_CHANNELS[@]}"; then
            send_cmd <<< ":l $uniq_chan"
        else
            send_cmd <<< ":j $uniq_chan"
        fi
    done
}
trap 'reload_config' SIGHUP SIGWINCH

# check for ncat, use bash tcp otherwise
# fail hard if user wanted tls and ncat not found
if [ -z "$(which ncat 2>/dev/null)" ]; then
        echo "*** NOTICE *** ncat not found; using bash tcp"
    [ -n "$TLS" ] && 
        die "TLS does not work with bash tcp"
    BASH_TCP=a
fi

# use default nick if not set, should be set
if [ -z "$NICK" ]; then
    echo "*** NOTICE *** nick was not specified; using ircbashbot"
    NICK="ircbashbot"
fi

# Connect to server
[ -n "$TLS" ] && TLS="--ssl"
if [ -z "$BASH_TCP" ]; then
    exec 3<> "$infile" ||
        die "unknown failure mapping named pipe ($infile) to fd"
    exec 4<> "$outfile" ||
        die "unknown failure mapping named pipe ($outfile) to fd"
    ( ncat "$SERVER" "$PORT" "$TLS" <&3 >&4
      kill -TERM $$ ) &
else
    infile="/dev/tcp/${SERVER}/${PORT}"
    exec 3<> "$infile" ||
        die "Cannot connect to ($SERVER) on port ($PORT)"
    exec 4<&3 ||
        die "unknown failure mapping named pipe ($infile) to fd"
fi

#################
# Other Helpers #
#################

# After server "identifies" the bot
# joins all channels
# identifies with nickserv
# NOTE: does not determine if 
#       nickserv is available
post_ident() {
    # join chans
    local CHANNELS_
    CHANNELS_=$(printf ",%s" "${CHANNELS[@]}")
    # channels are repopulated on JOIN commands
    # to better reflect joined channel realities
    CHANNELS=()
    # list join channels
    send_cmd <<< ":j ${CHANNELS_:1}"
    # ident with nickserv
    if [ -n "$NICKSERV" ]; then
        # bypass logged send_cmd/send_msg
        printf "%s\r\n" "PRIVMSG NickServ :IDENTIFY $NICKSERV" >&3
    fi
}

# logger function that checks log level
# $1 - log level of message
# $2 - the message
send_log() {
    local log_lvl
    case $1 in
        STDOUT)
            [ -n "$LOG_STDOUT" ] &&
                echo "$2"
            return
        ;;
        WARNING) log_lvl=3 ;;
        INFO)    log_lvl=2 ;;
        DEBUG)   log_lvl=1 ;;
        *)       log_lvl=4 ;;
    esac
    
    (( log_lvl >= LOG_LEVEL )) &&
        echo "*** $1 *** $2"
}

# any literal argument/s will be sent
# must be a valid IRC command string
send_msg() {
    printf "%s\r\n" "$*" >&3
    send_log "DEBUG" "SENT -> $*"
}

# function which converts bash-ircbot
# commands to IRC messages
# must be piped or heredoc; no arguments
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
            :le|:loge)
                send_log "ERROR" "$arg $other"
                ;;
            :lw|:logw)
                send_log "WARNING" "$arg $other"
                ;;
            :li|:log)
                send_log "INFO" "$arg $other"
                ;;
            :ld|:logd)
                send_log "DEBUG" "$arg $other"
                ;;
            *)
                ;;
        esac
    done
}

# check if nick is in ignore list
# $1 - nick to check
check_ignore() {
    # if ignore list is defined
    # shellcheck disable=SC2153
    for nick in "${IGNORE[@]}"; do
        if [ "$nick" = "$1" ]; then
            send_log "DEBUG" "IGNORED -> $nick"
            return 1
        fi
    done
    if [ -n "$ANTISPAM" ] &&
        [ "$(grep -Fxc "$1" "$antispam")" -ge "${ANTISPAM_COUNT:-3}" ]
    then
        return 1
    fi
    return 0
}

#######################
# Bot Framework Logic #
#######################

# handle private messages and
# determine if the bot needs to react to message
# $1: channel
# $2: datetime
# $3: user
# $4: msg
handle_privmsg() {
    # private message to us
    # 5th argument is the $LIB_PATH
    if [ "$NICK" = "$1" ]; then
        # most servers require this "in spirit"
        # tell them what we are
        if [ "$message" = $'\001VERSION\001' ]; then
            echo -e ":mn $3 \001VERSION $VERSION\001"
            echo ":ld CTCP VERSION -> $3 <$3> $4"
            [ -n "$ANTISPAM" ] && echo "$3" >&5
            return
        fi

        [ -x "$LIB_PATH/$PRIVATE" ] || return
        "$LIB_PATH/$PRIVATE" \
            "$3" "$2" "$3" "$4" "$LIB_PATH"
        echo ":ld PRIV_MSG EVENT -> $3 <$3> $4"
        [ -n "$ANTISPAM" ] && echo "$3" >&5
        return
    fi

    # highlight event in message
    # 5th argument is the $LIB_PATH
    local highlight="$NICK.? (.*)"
    if [[ "$4" =~ $highlight ]]; then
        # shellcheck disable=SC2153
        [ -x "$LIB_PATH/$HIGHLIGHT" ] || return
        "$LIB_PATH/$HIGHLIGHT" \
            "$1" "$2" "$3" "${BASH_REMATCH[1]}" "$LIB_PATH"
        echo ":ld HIGHLIGHT EVENT -> $1 <$3> $4"
        [ -n "$ANTISPAM" ] && echo "$3" >&5
        return
    fi

    # 5th argument is the command string that matched
    # may be useful for scripts that are symlinked
    # to multiple commands
    read -r cmd args <<< "$4"
    local reg="^[${CMD_PREFIX}]${cmd:1}"
    if [[ "$cmd" =~ $reg ]]; then
        cmd="${cmd:1}"
        [ -n "${COMMANDS[$cmd]}" ] || return
        [ -x "$LIB_PATH/${COMMANDS[$cmd]}" ] || return
        "$LIB_PATH/${COMMANDS[$cmd]}" \
            "$1" "$2" "$3" "$args" "$cmd"
        echo ":ld COMMAND EVENT -> $cmd: $1 <$3> $args"
        [ -n "$ANTISPAM" ] && echo "$3" >&5
        return
    fi

    # fallback regex check on message
    # 5th arguemnt is the fully matched string
    for reg in "${!REGEX[@]}"; do
        if [[ "$4" =~ $reg ]]; then
            [ -x "$LIB_PATH/${REGEX[$reg]}" ] || return
            "$LIB_PATH/${REGEX[$reg]}" \
                "$1" "$2" "$3" "$4" "${BASH_REMATCH[0]}"
            echo ":ld REGEX EVENT -> $reg: $1 <$3> $4"
            [ -n "$ANTISPAM" ] && echo "$3" >&5
            return
        fi
    done
}

#######################
# start communication #
#######################

# ncat uses half-close and
# will not know if the server
# closed unless two buffered
# writes fail
# fd's on linux should be buffered
# so no race condition
if [ -z "$BASH_TCP" ]; then
    while sleep 10m; do
        echo -ne '\r\n' >&3
        echo -ne '\r\n' >&3
    done &
fi

# remove a nick from antispam list every x seconds
if [ -n "$ANTISPAM" ]; then
    exec 5<> "$antispam"
    trap 'require_fd' SIGUSR1
    while sleep "${ANTISPAM_TIMEOUT:-5s}"; do
        echo -n '' > "$antispam"
    done &
fi

send_log "DEBUG" "COMMUNICATION START"
# pass if server is private
# this is likely not required
if [ -n "$PASS" ]; then
    send_msg "PASS $PASS"
fi
# "Ident" information
send_msg "NICK $NICK"
send_msg "USER $NICK +i * :$NICK"
# IRC event loop
while read -r user command channel message; do
    # if ping request
    if [ "$user" = "PING" ]; then
        send_msg "PONG $command"
        continue
    fi
    # needs to be here, prior to pruning
    kick="${message% :*}"
    # clean up information
    user=$(sed 's/^:\([^!]*\).*/\1/' <<< "$user")
    datetime=$(date +"%Y-%m-%d %H:%M:%S")
    message=${message:1}
    message=${message%$'\r'}

    send_log "STDOUT" "$channel $datetime $command <$user> $message"

    # handle commands here
    case $command in
        # any channel message
        PRIVMSG) 
            check_ignore "$user" &&
            handle_privmsg "$channel" "$datetime" "$user" "$message" \
            | send_cmd &
        ;;
        # any other channel message
        # generally notices are not supposed
        # to be responded to, as a bot
        NOTICE)
            [ -z "$READ_NOTICE" ] && continue
            check_ignore "$user" &&
            handle_privmsg "$channel" "$datetime" "$user" "$message" \
            | send_cmd &
        ;;
        # when the bot joins a channel
        # or a regular user
        # bot only cares about when it joins
        JOIN)
            if [ "$user" = "$NICK" ]; then
                channel="${channel:1}"
                channel="${channel%$'\r'}"
                # channel joined add to list or channels
                CHANNELS+=("$channel")
                send_log "JOIN" "$channel"
            fi
        ;;
        # when a user leaves a channel
        # only care when bot leaves a channel for any reason
        PART)
            if [ "$user" = "$NICK" ]; then
                for i in "${!CHANNELS[@]}"; do
                    if [ "${CHANNELS[$i]}" = "$channel" ]; then
                        unset CHANNELS["$i"]
                    fi
                done
                send_log "PART" "$channel"
            fi
        ;;
        # only other way for the bot to be removed
        # from a channel
        KICK)
            if [ "$kick" = "$NICK" ]; then
                for i in "${!CHANNELS[@]}"; do
                    if [ "${CHANNELS[$i]}" = "$channel" ]; then
                        unset CHANNELS["$i"]
                    fi
                done
                send_log "KICK" "$channel"
            fi
        ;;
        # Server confirms we are "identified"
        # we are ready to join channels and start
        004)
            # this should only happen once?
            post_ident
            send_log "DEBUG" "POST-IDENT PHASE, BOT READY"
        ;;
        # PASS command failed
        464)
            die 'INVALID PASSWORD'
        ;;
        465)
            die 'YOU ARE BANNED'
        ;;
        # Nickname is already in use
        # add crap and try the new nick
        433)
            NICK="${NICK}_"
            send_msg "NICK $NICK"
            send_log "NICK" "NICK CHANGED TO $NICK"
        ;;
    esac
done <&4
