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
VERSION="bash-ircbot: v3.0.0"

# help info
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

# parse args
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

#################
# Configuration #
#################

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

# set default temp dir path if not set
if [ -z "$temp_dir" ]; then
    temp_dir=/tmp
fi

#######################
# Configuration Tests #
#######################

# check for ncat, use bash tcp otherwise
# fail hard if user wanted tls and ncat not found
if ! which ncat >/dev/null 2>&1; then
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

# fail if no server
if [ -z "$SERVER" ]; then
    die "A server must be defined; check the configuration."
fi

################
# IPC and Temp #
################

# named pipes to connect ncat to message loop
# shellcheck disable=SC2154
[ -d "$temp_dir/bash-ircbot" ] && rm -r "$temp_dir/bash-ircbot"
infile="$temp_dir/bash-ircbot/in" # in as in from the server
outfile="$temp_dir/bash-ircbot/out" # out as in to the server
mkdir -m 0770 "$temp_dir/bash-ircbot" ||
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
    mkdir "$antispam" ||
        die "couldn't make antispam directory"
fi

# add temp dir for plugins
PLUGIN_TEMP="$temp_dir/bash-ircbot/plugin"
mkdir "$PLUGIN_TEMP" ||
    die "failed to create plugin temp dir"
# this is for plugins, so export it
export PLUGIN_TEMP

####################
# Signal Listeners #
####################

# handler to terminate bot
# can not trap SIGKILL
# make sure you kill with SIGTERM or SIGINT
EXIT_STATUS=0
quit_prg() {
    pkill -P $$
    exec 3>&-
    exec 4>&-
    exec 5>&-
    rm -rf "$temp_dir/bash-ircbot"
    exit "$EXIT_STATUS"
}
trap 'quit_prg' SIGINT SIGTERM

# similar to above but with >0 exit code
exit_failure() {
    EXIT_STATUS=1
    quit_prg
}
trap 'exit_failure' SIGUSR1

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
    send_log 'DEBUG' 'CONFIG RELOAD TRIGGERED'
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
        printf "%s\r\n" "NICKSERV IDENTIFY $NICKSERV" >&3
    fi
    
    # join or part channels based on new channel list
    uniq_chan_list="$(
        printf '%s\n' "${_CHANNELS[@]}" "${CHANNELS[@]}" \
        | sort \
        | uniq -u
    )"
    for uniq_chan in $uniq_chan_list; do
        if contains_chan "$uniq_chan" "${_CHANNELS[@]}"; then
            send_cmd <<< ":l $uniq_chan"
        else
            send_cmd <<< ":j $uniq_chan"
        fi
    done
}
trap 'reload_config' SIGHUP SIGWINCH

####################
# Setup Connection #
####################

[ -n "$TLS" ] && TLS="--ssl"
# this mode should be used for testing only
if [ -n "$MOCK_CONN_TEST" ]; then
    # send irc communication to
    exec 4>&0 # from server - stdin
    exec 3<&1 # to   server - stdout
    exec 1>&-
    exec 1<&2 # remap stdout to err for logs
    # disable ncat half close check
    BASH_TCP=1
# Connect to server otherwise
elif [ -z "$BASH_TCP" ]; then
    exec 3<> "$outfile" ||
        die "unknown failure mapping named pipe ($outfile) to fd"
    exec 4<> "$infile" ||
        die "unknown failure mapping named pipe ($infile) to fd"
    ( ncat "$SERVER" "${PORT:-6667}" "$TLS" <&3 >&4
      echo 'ERROR :ncat has terminated' >&4 ) &
else
    infile="/dev/tcp/${SERVER}/${PORT}"
    exec 3<> "$infile" ||
        die "Cannot connect to ($SERVER) on port ($PORT)"
    exec 4<&3 ||
        die "unknown failure mapping named pipe ($infile) to fd"
fi

########################
# IRC Helper Functions #
########################

# After server "identifies" the bot
# joins all channels
# identifies with nickserv
# NOTE: ircd must implement NICKSERV command
#       This command is not technically a standard
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
        printf "%s\r\n" "NICKSERV IDENTIFY $NICKSERV" >&3
    fi
}

# logger function that outputs to stdout
# checks log level to determine 
# if applicable to be written
# $1 - log level of message
# $2 - the message
send_log() {
    local log_lvl
    case $1 in
        STDOUT)
            [ -n "$LOG_STDOUT" ] &&
                printf "%(%Y-%m-%d %H:%M:%S)T %s\n" '-1' "${2//[$'\n'$'\r']/}"
            return
        ;;
        WARNING) log_lvl=3 ;;
        INFO)    log_lvl=2 ;;
        DEBUG)   log_lvl=1 ;;
        *)       log_lvl=4 ;;
    esac
    
    (( log_lvl >= LOG_LEVEL )) &&
        printf "*** %s *** %s\n" "$1" "$2" 
}

# any literal argument/s will be sent as their own line
# must be valid IRC command string or strings
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
                # add space, assume enpty line is intentional
                send_msg "PRIVMSG $arg :$other"
                ;;
            :mn|:notice)
                send_msg "NOTICE $arg :$other"
                ;;
            :c|:ctcp)
                send_msg "PRIVMSG $arg :"$'\001'"$other"$'\001'
                ;;
            :n|:nick)
                send_msg "NICK $arg"
                ;;
            :q|:quit)
                send_msg "QUIT :$arg $other"
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
# also check if nick is associated with spam, if enabled
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
    if [ -n "$ANTISPAM" ]; then
        [ ! -f "$antispam/$1" ] && return 0
        if (( $(printf "%(%s)T") - $(date -r "$antispam/$1" +"%s") > 
              ${ANTISPAM_TIMEOUT:-30} )) 
        then
            rm "$antispam/$1"
        elif [ "$(wc -c < "$antispam/$1")" -ge \
               "${ANTISPAM_COUNT:-3}" ]
        then
            send_log 'DEBUG' "SPAMMER -> $1"
            return 1
        fi
    fi
    return 0
}

# check if nick is a "trusted gateway" as in a a nick 
# which is used by multiple individuals. 
# this checks a configurable list of nicks. 
#
# if the nick is not a trusted gateway, this function returns without
# doing anything
#
# Note that this function mutates message
# inputs such as user and message.
# gateway is assumed to prepend a nickname to the message
# like <the_gateway> <user1> msg
# if your gateway does not do this, please make an issue on github
# $1 the nickname
trusted_gateway() {
    local trusted
    for nick in "${GATEWAY[@]}"; do
        if [ "$1" = "$nick" ]; then
            trusted=1
            break;
        fi
    done
    [ -z "$trusted" ] && return 1
    
    # is a gateway user
    # this a mutation
    read -r newuser newmsg <<< "$message"
    # new msg without the gateway username
    message="$newmsg"
    # delete any brackets and special chars
    user=${newuser//[<>$'\002'$'\003']/}
    # delete control char prepended numbers if applicable
    user=${user##*[0-9]}
}

#######################
# Bot Message Handler #
#######################

# handle PRIVMSGs and NOTICEs and
# determine if the bot needs to react to message
# $1: channel
# $2: datetime - DEPRECATED, GENERATE YOUR OWN TIME
# $3: user
# $4: msg
handle_privmsg() {
    # private message to us
    # 5th argument is the command name
    if [ "$NICK" = "$1" ]; then
        # most servers require this "in spirit"
        # tell them what we are
        if [ "$message" = $'\001VERSION\001' ]; then
            echo -e ":mn $3 \001VERSION $VERSION\001"
            echo ":ld CTCP VERSION -> $3 <$3> $4"
            [ -n "$ANTISPAM" ] && printf "1" >> "$antispam/$3"
            return
        fi

        # similar to command, but no prefix
        read -r cmd args <<< "$4"
        # if invalid command
        if [ -z "${COMMANDS[$cmd]}" ]; then
            echo ":m $3 --- Invalid Command ---"
            # basically your "help" command
            cmd="${PRIVMSG_DEFAULT_CMD:-help}"        
        fi
        [ -x "$LIB_PATH/${COMMANDS[$cmd]}" ] || return
        [ -n "$ANTISPAM" ] && printf "1" >> "$antispam/$3"
        "$LIB_PATH/${COMMANDS[$cmd]}" \
            "$3" "$2" "$3" "$args" "$cmd"
        echo ":ld PRIVATE COMMAND EVENT -> $cmd: $3 <$3> $args"
        return
    fi

    # highlight event in message
    # 5th argument is the $LIB_PATH (deprecation risk)
    local highlight="$NICK.? (.*)"
    if [[ "$4" =~ $highlight ]]; then
        # shellcheck disable=SC2153
        [ -x "$LIB_PATH/$HIGHLIGHT" ] || return
        [ -n "$ANTISPAM" ] && printf "1" >> "$antispam/$3"
        "$LIB_PATH/$HIGHLIGHT" \
            "$1" "$2" "$3" "${BASH_REMATCH[1]}" "$LIB_PATH"
        echo ":ld HIGHLIGHT EVENT -> $1 <$3> $4"
        return
    fi

    # 5th argument is the command string that matched
    # may be useful for scripts that are linked
    # to multiple commands, allowing for different behavior
    # by command name
    read -r cmd args <<< "$4"
    local reg="^[${CMD_PREFIX}]${cmd:1}"
    if [[ "$cmd" =~ $reg ]]; then
        cmd="${cmd:1}"
        [ -n "${COMMANDS[$cmd]}" ] || return
        [ -x "$LIB_PATH/${COMMANDS[$cmd]}" ] || return
        [ -n "$ANTISPAM" ] && printf "1" >> "$antispam/$3"
        "$LIB_PATH/${COMMANDS[$cmd]}" \
            "$1" "$2" "$3" "$args" "$cmd"
        echo ":ld COMMAND EVENT -> $cmd: $1 <$3> $args"
        return
    fi

    # fallback regex check on message
    # 5th arguemnt is the fully matched string
    # odd number index should be the plugin
    # even should be command
    for (( i=0; i<${#REGEX[@]}; i=i+2 )); do
        if [[ "$4" =~ ${REGEX[$i]} ]]; then
            [ -x "$LIB_PATH/${REGEX[((i+1))]}" ] || return
            [ -n "$ANTISPAM" ] && printf "1" >> "$antispam/$3"
            "$LIB_PATH/${REGEX[((i+1))]}" \
                "$1" "$2" "$3" "$4" "${BASH_REMATCH[0]}"
            echo ":ld REGEX EVENT -> ${REGEX[$i]}: $1 <$3> $4"
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
    while sleep "${HALFCLOSE_CHECK:-3}m"; do
        echo -ne '\r\n' >&3
        echo -ne '\r\n' >&3
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
    elif [ "$user" = 'ERROR' ]; then # probably banned?
       send_log "CRITICAL" "${command:1} $channel $message"
       break
    fi
    # needs to be here, prior to pruning
    kick="${message% :*}"
    # clean up information
    # user=$(sed 's/^:\([^!]*\).*/\1/' <<< "$user")
    host="${user##*@}"
    user="${user%%\!*}"
    user="${user:1}"
    # NOTE: datetime is deprecated
    # datetime=$(date +"%Y-%m-%d %H:%M:%S")
    message=${message:1}
    message=${message%$'\r'}

    # check if gateway nick
    trusted_gateway "$user"

    send_log "STDOUT" "$channel $command <$user> $message"

    # handle commands here
    case $command in
        # any channel message
        PRIVMSG) 
            check_ignore "$user" &&
            handle_privmsg "$channel" "$host" "$user" "$message" \
            | send_cmd &
        ;;
        # any other channel message
        # generally notices are not supposed
        # to be responded to, as a bot
        NOTICE)
            [ -z "$READ_NOTICE" ] && continue
            check_ignore "$user" &&
            handle_privmsg "$channel" "$host" "$user" "$message" \
            | send_cmd &
        ;;
        # bot was invited to channel
        # so join channel
        INVITE)
            send_cmd <<< ":j $message"
            send_log "INVITE" "<$user> $message "
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
                send_log "KICK" "<$user> $channel [Reason: ${message#*:}]"
            fi
        ;;
        NICK)
            if [ "$user" = "$NICK" ]; then
                channel="${channel:1}"
                NICK="${channel%$'\r'}"
                send_log "NICK" "NICK CHANGED TO $NICK"
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
            send_log 'CRITICAL' 'INVALID PASSWORD'
            break
        ;;
        465)
            send_log 'CRITICAL' 'YOU ARE BANNED'
            break
        ;;
        # Nickname is already in use
        # add crap and try the new nick
        433|432)
            NICK="${NICK}_"
            send_msg "NICK $NICK"
            send_log "NICK" "NICK CHANGED TO $NICK"
        ;;
        # not an official command, this is for getting
        # key stateful variable from the bot for mock testing
        __DEBUG)
            # disable this if not in mock testing mode
            [ -z "$MOCK_CONN_TEST" ] && continue
            case $message in
                channels) echo "${CHANNELS[*]}" >&3 ;;
                nickname) echo "$NICK" >&3 ;;
                nickparse) echo "$user" >&3 ;; 
                hostparse) echo "$host" >&3 ;;
                chanparse) echo "$channel" >&3 ;;
                msgparse) echo "$message" >&3 ;;
                # echo invalid debug commands
                *) echo "$message" >&3 ;;
            esac
    esac
done <&4
send_log 'CRITICAL' 'Exited Event loop, exiting'
exit_failure
