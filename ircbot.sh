#!/usr/bin/env bash
# Copyright 2018 Anthony DeDominic <adedomin@gmail.com>
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
VERSION="bash-ircbot: v5.1.0"

# help info
usage() {
    cat << EOF >&2
usage: $0 [-c config]

    -c --config=path    A config file
    -o --log-out=file   A file to log to instead of stdout.
    -h --help           This message

If no configuration path is found or CONFIG_PATH is not set,
ircbot will assume the configuration is in the same directory
as the script.

For testing, you can set MOCK_CONN_TEST=<anything>
EOF
    exit 1
}

die() {
    echo "*** CRITICAL *** $1" >&2
    exit 1
}

# parse args
while (( $# > 0 )); do
    case "$1" in
        -c|--config)
            CONFIG_PATH="$2"
            shift
        ;;
        --config=*)
            CONFIG_PATH="${1#*=}"
        ;;
        -o|--log-out)
            exec 1<>"$2"
            exec 2>&1
            shift
        ;;
        --log-out=*)
            exec 1<>"${1#*=}"
            exec 2>&1
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
[[ -z "$CONFIG_PATH" ]] && {
    CONFIG_PATH="${BASH_SOURCE[0]%/*}/config.sh"
    [[ "$CONFIG_PATH" == "${BASH_SOURCE[0]}/config.sh" ]] &&
        CONFIG_PATH="./config.sh"
}

# load configuration
if [[ -f "$CONFIG_PATH" ]]; then
    # shellcheck disable=SC1090
    . "$CONFIG_PATH"
else
    echo "*** CRITICAL *** no configuration" >&2
    usage
fi

# set default temp dir path if not set
# should consider using /dev/shm unless your /tmp is a tmpfs
[[ -z "$temp_dir" ]] && temp_dir=/tmp

#######################
# Configuration Tests #
#######################

# check for ncat, use bash tcp otherwise
# fail hard if user wanted tls and ncat not found
if ! type ncat >/dev/null 2>&1; then
    echo "*** NOTICE *** ncat not found; using bash tcp"
    [[ -n "$TLS" ]] &&
        die "TLS does not work with bash tcp"
    BASH_TCP=a
fi

# use default nick if not set, should be set
if [[ -z "$NICK" ]]; then
    echo "*** NOTICE *** nick was not specified; using ircbashbot"
    NICK="ircbashbot"
fi

# fail if no server
if [[ -z "$SERVER" ]]; then
    die "A server must be defined; check the configuration."
fi

###############
# Plugin Temp #
###############

# shellcheck disable=SC2154
APP_TMP="$temp_dir/bash-ircbot.$$"
mkdir -m 0770 "$APP_TMP" ||
    die "failed to make temp directory, check your config"

# add temp dir for plugins
PLUGIN_TEMP="$APP_TMP/plugin"
mkdir "$PLUGIN_TEMP" ||
    die "failed to create plugin temp dir"
# this is for plugins, so export it
export PLUGIN_TEMP

#########
# State #
#########

# TODO: soon
#declare -A user_modes

# populate invites array to prevent duplicate entries
declare -A invites
if [[ -f "$INVITE_FILE" ]]; then
    while read -r channel; do
        invites[$channel]=1
    done < "$INVITE_FILE"
fi

declare -Ag antispam_list

# IGNORE to a hash
declare -A ignore_hash
for ign in "${IGNORE[@]}"; do
    ignore_hash[$ign]=1
done

####################
# Signal Listeners #
####################

# handler to terminate bot
# can not trap SIGKILL
# make sure you kill with SIGTERM or SIGINT
exit_status=0
quit_prg() {
    exec 3<&-
    exec 4<&-
    rm -rf -- "$APP_TMP"
    exit "$exit_status"
}
trap 'quit_prg' SIGINT SIGTERM

# similar to above but with >0 exit code
exit_failure() {
    exit_status=1
    quit_prg
}
trap 'exit_failure' SIGUSR1

# helper for channel config reload
# determine if chan is in channel list
contains_chan() {
  for chan in "${@:2}"; do
      [[ "$chan" == "$1" ]] && return 0
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
    local _nick="$NICK"
    # shellcheck disable=SC2153
    local _nickserv="$NICKSERV"
    local _channels=("${CHANNELS[@]}")
    # shellcheck disable=SC1090
    . "$CONFIG_PATH"
    # NICK changed
    if [[ "$NICK" != "$_nick" ]]; then
        send_msg "NICK $NICK"
    fi
    # pass change for nickserv
    if [[ "$NICKSERV" != "$_nickserv" ]]; then
        printf '%s\r\n' "NICKSERV IDENTIFY $NICKSERV" >&3
    fi

    # persist channel invites
    # shellcheck disable=SC2207
    [[ -f "$INVITE_FILE" ]] &&
        CHANNELS+=($(< "$INVITE_FILE"))

    declare -A uniq_chans
    for chan in "${_channels[@]}" "${CHANNELS[@]}"; do
        uniq_chans[$chan]+=1
    done

    for uniq_chan in "${!uniq_chans[@]}"; do
        (( ${#uniq_chans[$uniq_chan]} > 1 )) && continue
        if contains_chan "$uniq_chan" "${_channels[@]}"; then
            send_cmd <<< ":l $uniq_chan"
        else
            send_cmd <<< ":j $uniq_chan"
        fi
    done

    unset ignore_hash
    declare -Ag ignore_hash
    for ign in "${IGNORE[@]}"; do
        ignore_hash[$ign]=1
    done
}
trap 'reload_config' SIGHUP SIGWINCH

####################
# Setup Connection #
####################

TLS_OPTS=()
[[ -n "$TLS"             ]] && TLS_OPTS+=(--ssl)
[[ -n "$VERIFY_TLS"      ]] && TLS_OPTS+=(--ssl-verify)
[[ -n "$VERIFY_TLS_FILE" ]] && TLS_OPTS+=("--ssl-trustfile=$VERIFY_TLS_FILE")

# this mode should be used for testing only
if [[ -n "$MOCK_CONN_TEST" ]]; then
    # send irc communication to
    exec 4>&0 # from server - stdin
    exec 3<&1 # to   server - stdout
    exec 1>&-
    exec 1<&2 # remap stdout to err for logs
    # disable ncat half close check
    BASH_TCP=1
# Connect to server otherwise
elif [[ -z "$BASH_TCP" ]]; then
    coproc {
        ncat "${TLS_OPTS[@]}" "$SERVER" "${PORT:-6667}"
        echo 'ERROR :ncat has terminated'
    }
    # coprocs are a bit weird
    # subshells may not be able to r/w to these fd's normally
    # without reopening them
    exec 3<> "/dev/fd/${COPROC[1]}"
    exec 4<> "/dev/fd/${COPROC[0]}"
else
    exec 3<> "/dev/tcp/${SERVER}/${PORT}" ||
        die "Cannot connect to ($SERVER) on port ($PORT)"
    exec 4<&3
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
    local _channels
    # shellcheck disable=SC2207
    [[ -f "$INVITE_FILE" ]] &&
        CHANNELS+=($(< "$INVITE_FILE"))
    printf -v _channels ",%s" "${CHANNELS[@]}"
    # channels are repopulated on JOIN commands
    # to better reflect joined channel realities
    CHANNELS=()
    # list join channels
    send_cmd <<< ":j ${_channels:1}"
    # ident with nickserv
    if [[ -n "$NICKSERV" ]]; then
        # bypass logged send_cmd/send_msg
        printf '%s\r\n' "NICKSERV IDENTIFY $NICKSERV" >&3
    fi
}

# logger function that outputs to stdout
# checks log level to determine 
#
# if applicable to be written
# $1 - log level of message
# $2 - the message
send_log() {
    declare -i log_lvl
    case $1 in
        STDOUT)
            # shellcheck disable=2183
            [[ -n "$LOG_STDOUT" ]] &&
                printf '%(%Y-%m-%d %H:%M:%S)T %s\n' '-1' "${2//[$'\n'$'\r']/}"
            return
        ;;
        WARNING) log_lvl=3 ;;
        INFO)    log_lvl=2 ;;
        DEBUG)   log_lvl=1 ;;
        *)       log_lvl=4 ;;
    esac

    (( log_lvl >= LOG_LEVEL )) &&
        printf '*** %s *** %s\n' "$1" "$2"
}

# Send arguments to irc server.
# Most servers don't allow for string longer than 510+2 bytes
#
# $* - multiple strings to be sent.
send_msg() {
    printf '%s\r\n' "$*" >&3
    send_log "DEBUG" "SENT -> $*"
}

# function which converts sic/ircii-like
# commands to IRC messages.
# must be piped or heredoc; no arguments
#
# <STDIN> - valid bash-ircbot command string
# SEE     - README.md
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

# Match a string to the list of configured regexps to check
# $1      - string to try and match
# @return - regex command that should be ran
# @exit   - zero for match, nonzero for no match
check_regexp() {
    declare -i i

    for (( i=0; i < ${#REGEX[@]}; ++i )); do
        if [[ "$1" =~ ${REGEX[i]} ]]; then
            [[ -x "$LIB_PATH/${REGEX_CMD[i]}" ]] || return 1
            echo "$i"
            return 0
        fi
    done

    return 1
}

# stripped down version of privmsg checker
# determines if message qualifies for spam
# filtering
#
# $1 - channel
# $2 - username
# $3 - command
# $4 - full message
check_spam() {
    local cmd
    cmd="${3:1}"
    # shellcheck disable=SC2153
    if [[ "$1" != "$NICK" &&
          -z "${COMMANDS[${cmd:-zzzz}]}" &&
          "$3" != ?(@)$NICK?(:|,) ]] &&
        ! check_regexp "$4" >/dev/null
    then
        return 0
    fi

    # increment if command or hl event
    declare -i temp ttime
    temp="${antispam_list[$2]% *}"
    ttime="${antispam_list[$2]#* }"
    (( temp <= ${ANTISPAM_COUNT:-3} )) &&
        temp+=1

    declare -i counter current
    # shellcheck disable=SC2034
    current='SECONDS'

    (( ttime == 0 )) &&
        ttime='current'
    counter="( current - ttime ) / ${ANTISPAM_TIMEOUT:-10}"
    if (( counter > 0 )); then
        ttime='current'
        temp='temp - counter'
        (( temp < 0 )) &&
            temp=0
    fi

    antispam_list[$2]="$temp $ttime"

    if (( temp <= ${ANTISPAM_COUNT:-3} )); then
        return 0
    else
        send_log "DEBUG" "SPAMMER -> $2"
        return 1
    fi
}

# check if nick is in ignore list
#
# $1 - nick to check
# $2 - whole message to filter bots ?
check_ignore() {
    if [[ -n "${ignore_hash[$1]}" ]]; then
        send_log "DEBUG" "IGNORED -> $1"
        return 1
    fi
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
# $1 - the nickname
trusted_gateway() {
    local trusted
    for nick in "${GATEWAY[@]}"; do
        if [[ "$1" == "$nick" ]]; then
            trusted=1
            break;
        fi
    done
    [[ -z "$trusted" ]] && return 1

    # is a gateway user
    # this a mutation
    read -r newuser newmsg <<< "$message"
    # new msg without the gateway username
    message="$newmsg"
    # delete any brackets and some special chars
    user=${newuser//[<>$'\002'$'\003']/}
    # delete mIRC color prepended numbers if applicable
    [[ "$user" =~ ^[0-9,]*(.*)$ ]] &&
        user="${BASH_REMATCH[1]}"

    # some plugins like vote use hostname instead of username
    # this tries to a create a new vhost, though
    # vhosts like these could be technically made
    host="${user}.trusted-gateway.${host}"
}

#######################
# Bot Message Handler #
#######################

# TODO: note addition of usermode when available
# handle PRIVMSGs and NOTICEs and
# determine if the bot needs to react to message
# $1: channel - the channel the string came from
# $2: vhost   - the vhost of the user
# $3: user    - the nickname of the user
# $4: msg     - message minus command
# $5: cmd     - command name
# $6: full    - full message
handle_privmsg() {
    # private message to us
    # 5th argument is the command name
    if [[ "$NICK" == "$1" ]]; then
        # most servers require this "in spirit"
        # tell them what we are
        if [[ "$6" = $'\001VERSION\001' ]]; then
            echo ":ld CTCP VERSION -> $3 <$3>"
            echo ":mn $3 "$'\001'"VERSION $VERSION"$'\001'
            return
        fi

        cmd="$5"
        # if invalid command
        if [[ -z "${COMMANDS[$cmd]}" ]]; then
            echo ":m $3 --- Invalid Command ---"
            # basically your "help" command
            cmd="${PRIVMSG_DEFAULT_CMD:-help}"
        fi
        [[ -x "$LIB_PATH/${COMMANDS[$cmd]}" ]] || return
        echo ":ld PRIVATE COMMAND EVENT -> $cmd: $3 <$3> $4"
        "$LIB_PATH/${COMMANDS[$cmd]}" \
            "$3" "$2" "$3" "$4" "$cmd"
        return
    fi

    # highlight event in message
    if [[ "$5" = ?(@)$NICK?(:|,) ]]; then
        # shellcheck disable=SC2153
        [[ -x "$LIB_PATH/$HIGHLIGHT" ]] || return
        echo ":ld HIGHLIGHT EVENT -> $1 <$3>  $4"
        "$LIB_PATH/$HIGHLIGHT" \
            "$1" "$2" "$3" "$4" "$5"
        return
    fi

    # 5th argument is the command string that matched
    # may be useful for scripts that are linked
    # to multiple commands, allowing for different behavior
    # by command name
    case "${5:0:1}" in ["$CMD_PREFIX"])
        cmd="${5:1}"
        [[ -n "${COMMANDS[$cmd]}" &&
            -x "$LIB_PATH/${COMMANDS[$cmd]}" ]] || return
        echo ":ld COMMAND EVENT -> $cmd: $1 <$3> $4"
        "$LIB_PATH/${COMMANDS[$cmd]}" \
            "$1" "$2" "$3" "$4" "$cmd"
        return
    esac

    # regexp check.
    if RMATCH_IND="$(check_regexp "$6")"; then
        echo ":ld REGEX EVENT -> ${REGEX[RMATCH_IND]}: $1 <$3> $6 (${BASH_REMATCH[0]})"
        "$LIB_PATH/${REGEX_CMD[RMATCH_IND]}" \
            "$1" "$2" "$3" "$6" \
            "${REGEX[RMATCH_IND]}" \
            "${BASH_REMATCH[0]}"
        return
    fi
}

#######################
# start communication #
#######################

[[ -z "$TIMEOUT_CHECK" ]] &&
    TIMEOUT_CHECK=300
# keeps the connection active.
# don't bother if we are in testing mode.
if [[ -z "$MOCK_CONN_TEST" ]]; then
    while sleep "$(( TIMEOUT_CHECK / 2 ))"; do
        send_msg "PING :$NICK"
    done &
fi

send_log "DEBUG" "COMMUNICATION START"
# pass if server is private
# this is likely not required
if [[ -n "$PASS" ]]; then
    send_msg "PASS $PASS"
fi
# "Ident" information
send_msg "NICK $NICK"
send_msg "USER $NICK +i * :$NICK"
# IRC event loop
# note if the irc sends lines longer than
# 1024 bytes, it may fail to parse
while read -u 4 -r -n 1024\
    -t "$TIMEOUT_CHECK" \
    user command channel message
do
    # check for high level commands from the ircd
    case "$user" in
        PING) # have to reply
            send_msg "PONG $command"
            continue
        ;;
        ERROR) # banned?
            send_log "CRITICAL" "${command:1} $channel $message"
            break
        ;;
    esac
    # needs to be declared here
    # prior to any parsing
    kick="${message% :*}"
    # clean and split out user information
    host="${user##*@}"
    user="${user%%\!*}"
    user="${user:1}"
    # remove leading colon and carriage return
    message=${message:1}
    message=${message%$'\r'}

    # check if gateway nick
    trusted_gateway "$user"

    # log message
    send_log "STDOUT" "$channel $command <$user> $message"

    # split command from message
    read -r cmd msg <<< "$message"

    # handle commands here
    case $command in
        # any channel message
        PRIVMSG)
            # this step has to occur in the main loop sadly
            if [[ -n "$ANTISPAM" ]]; then
                check_spam "$channel" "$user" "$cmd" "$message" ||
                    continue
            fi
            check_ignore "$user" &&
            handle_privmsg \
                "$channel" \
                "$host" \
                "$user" \
                "$msg" \
                "$cmd" \
                "$message" \
            | send_cmd &
        ;;
        # any other channel message
        # generally notices are not supposed
        # to be responded to, as a bot
        NOTICE)
            [[ -z "$READ_NOTICE" ]] && continue
            # this step has to occur in the main loop sadly
            if [[ -n "$ANTISPAM" ]]; then
                check_spam "$channel" "$user" "$cmd" "$message" ||
                    continue
            fi
            check_ignore "$user" &&
            handle_privmsg \
                "$channel" \
                "$host" \
                "$user" \
                "$msg" \
                "$cmd" \
                "$message" \
            | send_cmd &
        ;;
        # bot was invited to channel
        # so join channel
        INVITE)
            send_cmd <<< ":j $message"
            send_log "INVITE" "<$user> $message "
            [[ -n "$INVITE_FILE" && "${invites[$message]}" != 1 ]] && {
                echo "$message" >> "$INVITE_FILE"
                invites[$message]=1
            }
        ;;
        # when the bot joins a channel
        JOIN)
            if [[ "$user" = "$NICK" ]]; then
                channel="${channel:1}"
                channel="${channel%$'\r'}"
                # channel joined add to list or channels
                CHANNELS+=("$channel")
                send_log "JOIN" "$channel"
            fi
        ;;
        # when the bot leaves a channel
        PART)
            if [[ "$user" = "$NICK" ]]; then
                for i in "${!CHANNELS[@]}"; do
                    if [[ "${CHANNELS[$i]}" = "$channel" ]]; then
                        unset CHANNELS["$i"]
                    fi
                done
                send_log "PART" "$channel"
            fi
        ;;
        # only way for the bot to be removed
        # from a channel, other than config reload
        KICK)
            if [[ "$kick" = "$NICK" ]]; then
                for i in "${!CHANNELS[@]}"; do
                    if [[ "${CHANNELS[$i]}" = "$channel" ]]; then
                        unset CHANNELS["$i"]
                    fi
                done
                send_log "KICK" "<$user> $channel [Reason: ${message#*:}]"
            fi
        ;;
        NICK)
            if [[ "$user" = "$NICK" ]]; then
                channel="${channel:1}"
                [[ -z "$orig_nick" ]] && orig_nick="$NICK"
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
            [[ -z "$orig_nick" ]] && orig_nick="$NICK"
            NICK="${NICK}_"
            case "$NICK" in
                # attempted to change nick 4 times
                "${orig_nick}"____)
                    send_log 'CRITICAL' 'FAILED TO CHANGE NICK THREE TIMES'
                    break
                ;;
            esac
            send_msg "NICK $NICK"
            send_log "NICK" "NICK CHANGED TO $NICK"
        ;;
        PONG)
            send_log 'DEBUG' 'RECV -> PONG'
        ;;
        # not an official command, this is for getting
        # key stateful variable from the bot for mock testing
        __DEBUG)
            # disable this if not in mock testing mode
            [[ -z "$MOCK_CONN_TEST" ]] && continue
            case $message in
                channels) echo "${CHANNELS[*]}" >&3 ;;
                nickname) echo "$NICK" >&3 ;;
                nickparse) echo "$user" >&3 ;;
                hostparse) echo "$host" >&3 ;;
                chanparse) echo "$channel" >&3 ;;
                msgparse) echo "$message" >&3 ;;
                *) echo "$message" >&3 ;;
            esac
        ;;
    esac
done
send_log 'CRITICAL' 'Exited Event loop; timed out or disconnected.'
exit_failure
