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
VERSION="neo8ball: v2021.4.17"

echo1() {
    printf '%s\n' "$*"
}

echo2() {
    printf >&2 '%s\n' "$*"
}

# help info
usage() {
    echo2 \
'usage: '"$0"' [-c config] [-o logfile] [-t]

    -t --timestamp      Timestamp logs using iso-8601.
    -c --config=file    A neo8ball config.sh
    -o --log-out=file   A file to log to instead of stdout.
    -h --help           This message.

If no configuration path is found or CONFIG_PATH is not set,
ircbot will assume the configuration is in the same directory
as the script.

For testing, you can set MOCK_CONN_TEST=<anything>'
    exit 1
}


die() {
    echo2 "*** CRITICAL *** $1"
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
        -t|--timestamp)
            LOG_TSTAMP_FORMAT='%(%Y-%m-%dT%H:%M:%S%z)T '
            LOG_TSTAMP_ARG1=-1
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
}

# load configuration
if [[ -f "$CONFIG_PATH" ]]; then
    # shellcheck disable=SC1090
    . "$CONFIG_PATH"
else
    echo2 '*** CRITICAL *** no configuration'
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
    echo1 "*** NOTICE *** ncat not found; using bash tcp"
    [[ -n "$TLS" ]] &&
        die "TLS does not work with bash tcp"
    BASH_TCP=a
fi

# use default nick if not set, should be set
if [[ -z "$NICK" ]]; then
    echo1 "*** NOTICE *** nick was not specified; using ircbashbot"
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

# describes modes of users on a per channel basis
declare -A user_modes

# populate invites array to prevent duplicate entries
declare -A invites
if [[ -f "$INVITE_FILE" ]]; then
    while read -r channel; do
        [[ -z "$channel" ]] && continue
        invites[$channel]=1
    done < "$INVITE_FILE"
fi

declare -Ag antispam_list

# IGNORE to a hash
declare -A ignore_hash
for ign in "${IGNORE[@]}"; do
    ignore_hash[$ign]=1
done

# if REGEX_ORDERED not defined, build it here
if [[ "${#REGEX_ORDERED[@]}" == 0 ]]; then
    REGEX_ORDERED=("${!REGEX[@]}")
fi

####################
# Signal Listeners #
####################

# handler to terminate bot on TERM | INT
exit_status=0
quit_prg() {
    exec 3<&-
    exec 4<&-
    [[ -n "$ncat_pid" ]] &&
        kill -- "$ncat_pid"
    rm -rf -- "$APP_TMP"
    exit "$exit_status"
}
trap 'quit_prg' SIGINT SIGTERM

# similar to above but with >0 exit code
exit_failure() {
    exit_status=1
    quit_prg
}

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
        send_log "DEBUG" "SENT -> NICKSERV IDENTIFY <PASSWORD>"
    fi

    # persist channel invites
    # shellcheck disable=SC2207
    [[ -f "$INVITE_FILE" ]] &&
        CHANNELS+=($(< "$INVITE_FILE"))

    declare -A uniq_chans
    for chan in "${_channels[@]}" "${CHANNELS[@]}"; do
        uniq_chans[$chan]+=1
    done

    declare -a leave_list=()
    declare -a join_list=()
    local jlist='' llist=''
    for uniq_chan in "${!uniq_chans[@]}"; do
        (( ${#uniq_chans[$uniq_chan]} > 1 )) && continue
        if contains_chan "$uniq_chan" "${_channels[@]}"; then
            leave_list+=("$uniq_chan")
        else
            join_list+=("$uniq_chan")
        fi
    done

    if [[ "${#join_list[@]}" -gt 0 ]]; then
        printf -v jlist ',%s' "${join_list[@]}"
        send_large_join_part ':j' "${jlist:1}"
    fi

    if [[ "${#leave_list[@]}" -gt 0 ]]; then
        printf -v llist ',%s' "${leave_list[@]}"
        send_large_join_part ':l' "${llist:1}"
    fi
    

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
if [[ -n "$TLS" ]]; then
    TLS_OPTS+=('--ssl')
    # default verify
    [[ -n "${VERIFY_TLS-y}" ]] &&
        TLS_OPTS+=('--ssl-verify')
    [[ -n "$VERIFY_TLS_FILE" ]] &&
        TLS_OPTS+=('--ssl-cert' "$VERIFY_TLS_FILE")
fi

# this mode should be used for testing only
if [[ -n "$MOCK_CONN_TEST" ]]; then
    echo2 'IN MOCK'
    # send irc communication to
    exec 4>&0 # from server - stdin
    exec 3<&1 # to   server - stdout
    exec 1>&-
    exec 1<&2 # remap stdout to err for logs
# Connect to server otherwise
elif [[ -z "$BASH_TCP" ]]; then
    coproc {
        ncat "${TLS_OPTS[@]}" "${SERVER:-irc.rizon.net}" "${PORT:-6667}"
        echo1 'ERROR :ncat has terminated'
    }
    ncat_pid="$COPROC_PID"
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

all_control_characters=$'\1\2\3\4\5\6\7\10\11\12\13\14\15\16\17\20\21\22\23\24\25\26\27\30\31\32\33\34\35\36\37'

## helper for iterating over a string using a given delimiter
##
## iter_tokenize/2:
##   $1: 'init' - Initialize tokenizer.
##   $2         - String to tokenize.
##
## iter_tokenize/1:
##   $1 - Delimit string with this character,
##        consumes and returns remaining string if no such delimiter found.
##
## iter_tokenize/0:
##   Test if iterator is done. Returns _iter_remain.
##
## mutates _iter_remain - unprocessed parts of the string.
## mutates REPLY        - The next token found, or the remainder of the string.
##
## returns: (0|1) - 1 if no more input, 0 otherwise.
#__iter_stack=()
iter_tokenize() {
    if [[ "$1" == 'init' && -n "$2" ]]; then
        _iter_remain="$2"
        REPLY=
        return 0
    # Unused for now....
    #elif [[ "$1" == 'state' && "$2" == 'push' ]]; then
    #    __iter_stack+=("$__iter_remain")
    #    if [[ -n "$3" ]]; then
    #        __iter_remain="$3"
    #    else
    #        __iter_remain=''
    #    fi
    #    REPLY=
    #elif [[ "$1" == 'state' && "$2" == 'pop' ]]; then
    #    __iter_remain="${__iter_stack[-1]}"
    #    __iter_stack+=("${__iter_stack[@]:0:${#__iter_stack[@]}-1}")
    #    REPLY=
    elif [[ -z "$_iter_remain" ]]; then
        REPLY=
        return 1
    elif [[ -n "$1" ]]; then
        REPLY="${_iter_remain%%"$1"*}"
        if [[ "${_iter_remain#"$REPLY$1"}" == "$_iter_remain" ]]; then
            _iter_remain=
        else
            _iter_remain="${_iter_remain#"$REPLY$1"}"
        fi
        return 0
    else # Iterator is not done.
        REPLY="$_iter_remain"
        return 0
    fi
}

# Parse a given IRC message.
# e.g. :some!message!host VERB param1 param2 param3
# into user=some
#      host=host
#      sender=some!message!host
#      command=VERB
#      params=(param1 param2 param3)
#
# $1 - the full message to parse. may include or disclude \r
#
# mutates: sender  - the user who sent the message.
# mutates: command - the IRC verb associated with the msessage.
# mutates: params  - The params associated with this message.
# mutates: user    - actually the nickname of the sender.
# mutates: host    - the "hostname" associated with the sender.
parse_irc() {
    # TODO: enable IRCv3 tags
    # local state=tags
    # ttags=

    local state='sender'
    sender=
    command=
    params=()
    iter_tokenize init "${1%$'\r'}"
    while iter_tokenize ' '; do
        # we only consume extra spaces in the trailing parameter.
        [[ "$REPLY" == '' ]] && continue
        case "$state" in
            sender)
                case "$REPLY" in
                    :*)
                        sender="${REPLY#:}"
                        state='command'
                    ;;
                    *)
                        command="$REPLY"
                        state='params'
                    ;;
                esac
            ;;
            command)
                command="$REPLY"
                state='params'
            ;;
            params)
                case "$REPLY" in
                    :*)
                        local t="$REPLY"
                        iter_tokenize
                        params+=("${t#:}${REPLY:+" $REPLY"}")
                        break
                    ;;
                    *)
                        params+=("$REPLY")
                    ;;
                esac
            ;;
        esac
    done

    # parser sender into pieces
    iter_tokenize init "$sender"
    iter_tokenize '!'
    user="$REPLY"
    iter_tokenize '@'
    # ignored for now
    # user="$REPLY"
    iter_tokenize
    host="$REPLY"
}

# Takes a user mode as stored in $user_modes and returns a single char
# representing the user's highest chan mode.
#
# Possible values of REPLY:
# q  - OWNER
# a  - ADMIN
# o  - OPERATOR
# h  - HALF-OP
# v  - VOICED
# '' - nothing
#
# $1             - the modebits
# mutates: REPLY - empty if user has no modes or a single char.
modebit_to_char() {
    local mode="$1"
    if ((   (mode & 2#10000) > 0 )); then
        REPLY='q'
    elif (( (mode & 2#01000) > 0 )); then
        REPLY='a'
    elif (( (mode & 2#00100) > 0 )); then
        REPLY='o'
    elif (( (mode & 2#00010) > 0 )); then
        REPLY='h'
    elif (( (mode & 2#00001) > 0 )); then
        REPLY='v'
    else
        REPLY=
    fi
}

# inverse of modebit_to_char
# $1             - get the value of this given char
# mutates: REPLY - value of $1 in modebits.
char_to_modebit() {
    case "$1" in
        'v'|'+') REPLY='2#00001' ;;
        'h'|'%') REPLY='2#00010' ;;
        'o'|'@') REPLY='2#00100' ;;
        'a'|'&') REPLY='2#01000' ;;
        'q'|'~') REPLY='2#10000' ;;
        *)       REPLY='0' ;;
    esac
}

# Add a given mode to a user.
#
# $1 - channel where this happened
# $2 - user who is affected
# $3 - the mode bit converted by char_to_modebit()
add_user_mode() {
    local channel="$1"
    local user="$2"
    local modebit="$3"

    local chr_mode="${user_modes["$channel $user"]}"
    send_log 'DEBUG' "$channel <$user> MODE bits BEFORE: $chr_mode"
    if [[ -z "$chr_mode" ]]; then
        user_modes["$channel $user"]="$modebit"
    else
        user_modes["$channel $user"]="$(( chr_mode | modebit ))"
    fi
    send_log 'DEBUG' "$channel <$user> MODE bits AFTER: $(( chr_mode | modebit ))"
}

# Remove a given mode to a user.
#
# $1 - channel where this happened
# $2 - user who is affected
# $3 - the mode bit converted by char_to_modebit()
clear_user_mode() {
    local channel="$1"
    local user="$2"
    local modebit="$3"

    local chr_mode="${user_modes["$channel $user"]}"
    send_log 'DEBUG' "$channel <$user> MODE bits BEFORE: $chr_mode"
    if [[ -z "$chr_mode" ]]; then
        user_modes["$channel $user"]="0"
    else
        user_modes["$channel $user"]="$(( chr_mode & (~modebit) ))"
    fi
    send_log 'DEBUG' "$channel <$user> MODE bits AFTER: $(( chr_mode & (~modebit) ))"
}
# Parse the 353 NAMES / NAMESX reply message.
#
# $1 - channel
# $2 - the string from the irc server with all the usernames (\w mode)
mode_chars='+%@&~'
parse_353() {
    local channel="$1"
    iter_tokenize init "$2"
    while iter_tokenize ' '; do
        local user="$REPLY"
        local mode_string="${user##*["$mode_chars"]}"
        mode_string="${user%"$mode_string"}"
        user="${user##*["$mode_chars"]}"
        # make sure we zero out the user's mode.
        user_modes["$channel $user"]='2#00000';

        while [[ -n "$mode_string" ]]; do
            local mode_chr="${mode_string:0:1}"
            local mode_string="${mode_string:1}"
            char_to_modebit "$mode_chr"
            mode_chr="$REPLY"
            add_user_mode "$channel" "$user" "$mode_chr"
        done
    done
}

# Parse only CHANMODES=A,B,C,D
# where A = 1 ALWAYS has a parameter (Address | nick)
#       B = 2 ALWAYS has a parameter (channel setting)
#       C = 3 parameter only when +. - has no parameter
#       D = 4 NEVER has a parameter.
# Fill with *sane* defaults in case we never get 005
declare -A ISUPPORT_CHANMODES=(
    [b]=1 # ban
    [e]=1 # exempt (from ban)
    [I]=1 # invite-exempt (from chan mode +i)
    [k]=2 # key
    [l]=3 # channel limit (-l has no param, +l does)
    # Assume rest are 4. We don't care about 4.
)
# parse the ISUPPORT key value pairs
# params could go from 1 to ~13 key value pairs
#
# $@ - array of parameters from ISUPPORT, only CHANMODES= is used.
parse_005() {
    for arg; do
        local value="${arg#*=}"
        local key="${arg%"$value"}"
        case "$key" in
            CHANMODES)
                ISUPPORT_CHANMODES=()
                iter_tokenize init "$value"
                # 1(a),2(b),3(c),4(d)
                # we can ignore type 4(d) completely as these
                # are primarily user modes and they have no value
                # to channel mode tracking we care about (as a bot).
                local mode_type=1
                while iter_tokenize ','; do
                    local modes="$REPLY"
                    while [[ -n "$modes" ]]; do
                        local mode_chr="${modes:0:1}"
                        local modes="${modes:1}"
                        ISUPPORT_CHANMODES["$mode_chr"]="$mode_type"
                    done
                    mode_type="$(( mode_type + 1 ))"
                done
                return 0
            ;;
            *) ;;
        esac
    done
}

# checks ISUPPORT_CHANMODES, or if it is a user prefix (q,a,o,h,v),
# requires a parameter.
#
# $1 - the signedness of the mode (+|-)
# $2 - the mode
#
# returns: 0 if the given mode requires a parameter.
has_parameter_mode() {
    case "$2" in
        q|a|o|h|v) return 0 ;;
    esac

    local m="${ISUPPORT_CHANMODES[$2]}"
    case "$m" in
        1|2) return 0 ;;
        3) [[ "$1" == '+' ]] && return 0 ;;
    esac
    return 1
}

# This command is difficult to understand.
# As far as I can tell based on reading the spec at least twice:
#  MODE reply returns to the user something like #channel +|-somemodes param param2, etc...
#  Where you must first pregather all the modes that take a parameter (see CHANMODES ISUPPORT 005)
#  and then first in, first out, match them to the modes being set.
#  If this is incorrect, please help me understand by opening an issue.
#
# e.g.
#  +bv banned!user@param -o voiced_user deop_user
#  +b -> banned!user@param
#  +v -> voiced_user
#  -o -> deop_user
#
# $1     - channel these modes manipulate.
# ${@:1} - the rest of the mode line.
# returns: 1 if failed to correctly parse the MODE command.
parse_mode() {
    local channel="$1"
    shift # rest are "mode strings"

    local cmode_type=
    local cmodes=()
    local params=()
    local mode_line=
    
    for mode_line; do
        case "$mode_line" in
            '-'*|'+'*)
                while [[ -n "$mode_line" ]]; do
                    local mode_chr="${mode_line:0:1}"
                    local mode_line="${mode_line:1}"
                    if [[ "$mode_chr" == "+" || "$mode_chr" == '-' ]]
                    then
                        cmode_type="$mode_chr"
                    elif has_parameter_mode "$cmode_type" "$mode_chr"
                    then
                        cmodes+=("${cmode_type}${mode_chr}")
                    fi
                done
            ;;
            '') continue ;;
            *) params+=("$mode_line") ;;
        esac
    done

    # assert
    if [[ "${#cmodes[@]}" != "${#params[@]}" ]]; then
        send_log 'ERROR' \
                 'Something is wrong with the MODE parser or the server.'
        send_log 'ERROR' \
                 'Number of modes to apply do not match up with number of parameters.'
        send_log 'INFO' \
                 'Using NAMES command to attempt to recover Channel Modes.'
        send_msg "NAMES $channel"
        return 1
    fi

    local len="${#cmodes[@]}"

    for (( i=0; i<len; ++i )); do
        local m="${cmodes[i]}"
        case "$m" in
            +q|+a|+o|+h|+v)
                char_to_modebit "${m:1:1}"
                send_log 'DEBUG' "$REPLY"
                local mv="$REPLY"
                local user="${params[i]}"
                add_user_mode "$channel" "$user" "$mv"
            ;;
            -q|-a|-o|-h|-v)
                char_to_modebit "${m:1}"
                send_log 'DEBUG' "$REPLY"
                local mv="$REPLY"
                local user="${params[i]}"
                clear_user_mode "$channel" "$user" "$mv"
            ;;
        esac
    done
    return 0
}

# parse all the capabilites we support.
#
# $1 - ACK or NAK of capability
# $2 - message body to parse, all the capabilites we requested.
#
# returns: 1 if we didn't get the capabilites we need.
parse_cap() {
    local ack="$1"
    local message="$2"
    local defer_cap_end=
    iter_tokenize init "$message"
    while iter_tokenize ' '; do
        case "$REPLY" in
            sasl)
                if [[ "$ack" == "ACK" ]]; then
                    send_msg 'AUTHENTICATE PLAIN'
                    defer_cap_end=1
                else
                    send_log 'CRITICAL' \
                             'Server does not support SASL, but SASL_PASS was configured.'
                    return 1
                fi
            ;;
            # We need this for proper mode tracking
            # NAMES reply will show *ALL* user-specific channel modes.
            # this mode should only be REQd if TRACK_CHAN_MODE=1
            multi-prefix)
                if [[ "$ack" == "NAK" ]]; then
                    send_log 'CRITICAL' \
                             'Server does not support multi-prefix, but TRACK_CHAN_MODE was configured.'
                    return 1
                fi
            ;;
            *)
                send_log 'WARNING' \
                         'We were told about '"$REPLY"' capability with status '"$ack"', but we never asked for it.'
            ;;
        esac
    done
    if [[ -z "$defer_cap_end" ]]; then
        send_msg 'CAP END'
    fi
    return 0
}

# long joins can be truncated and
# rapidly joining multiple channels at once generally triggers
# some server side antispam
#
# $1 part or join command (:l, :j)
# $2 a comma delimited string of channels
send_large_join_part() {
    # assume all chars are 8bit
    local LANG=C
    local join_len="${#2}"
    if (( join_len < 500 )); then
        send_cmd <<< "$1 $2"
        return
    fi

    local join_partial=
    iter_tokenize init "$2"
    while iter_tokenize ','; do
        local channel="$REPLY"
        if (( (${#join_partial} + ${#channel}) < 500 )); then
            join_partial+=",$channel"
        else
            send_cmd <<< "$1 ${join_partial:1}"
            join_partial=",$channel"
        fi
    done
    [[ -n "$join_partial" ]] &&
        send_cmd <<< "$1 ${join_partial:1}"
}

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
    send_large_join_part ':j' "${_channels:1}"
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
    local clean_log_msg="${2//["$all_control_characters"]/}"

    case $1 in
        STDOUT)
            # shellcheck disable=2183
            [[ -n "$LOG_STDOUT" ]] &&
                printf '%(%Y-%m-%d %H:%M:%S%z)T %s\n' '-1' "$clean_log_msg"
            return
        ;;
        WARNING) log_lvl=3 ;;
        INFO)    log_lvl=2 ;;
        DEBUG)   log_lvl=1 ;;
        *)       log_lvl=4 ;;
    esac

    (( log_lvl >= LOG_LEVEL )) &&
        printf "$LOG_TSTAMP_FORMAT"'*** %s *** %s\n' $LOG_TSTAMP_ARG1 "$1" "$clean_log_msg"
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
# $1      - OPTIONAL the user/channel to reply to when using the :reply :r command. 
# <STDIN> - valid bash-ircbot command string
# SEE     - README.md
send_cmd() {
    local reply_to="$1"
    while read -r; do
        cmd="${REPLY%% *}"

        if [[ "$REPLY" == "${REPLY#"$cmd"* }" ]]; then
            cmd="$cmd"' - ERR_NO_ARGS'
            arg="<NO ARG>"
        else
            arg="${REPLY#"$cmd"* }"
            arg="${arg%% *}"
        fi

        # OTHER ARG must be exactly one space after ARG
        if [[ "$REPLY" == "${REPLY#"$cmd"*' '"$arg"' '}" ]]; then
            other=
        else
            other="${REPLY#"$cmd"*' '"$arg"' '}"
        fi

        case $cmd in
            :j|:join)
                send_msg "JOIN $arg"
            ;;
            :jd|:delay-join)
                sleep "$arg"
                send_msg "JOIN $other"
            ;;
            :l|:leave)
                send_msg "PART $arg :$other"
            ;;
            :m|:message)
                send_msg "PRIVMSG $arg :$other"
            ;;
            :md|:delay-message)
                sleep "$arg"
                send_msg "PRIVMSG ${other% *} :${other#* }"
            ;;
            :mn|:notice)
                send_msg "NOTICE $arg :$other"
            ;;
            :nd|:delay-notice)
                sleep "$arg"
                send_msg "NOTICE ${other% *} :${other#* }"
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
            :r|:reply)
                if [[ -n "$reply_to" ]]; then
                    send_msg "PRIVMSG $reply_to :${arg}${other:+ "$other"}"
                else
                    send_log "ERROR" \
                             "Plugin attempted to use the reply command but we don't have a reply_to."
                fi
            ;;
            :raw)
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
                send_log "ERROR" "Invalid command: ($cmd) args: ($arg $other)"
            ;;
        esac
    done
}

# Match a string to the list of configured regexps to check.
#
# $1             - String to try and match.
# mutates: REPLY - Which will contain any matching regexp.
# returns:       - 0 if REPLY contains a regexp match.
check_regexp() {
    local regex

    for regex in "${REGEX_ORDERED[@]}"; do
        if [[ "$1" =~ $regex ]]; then
            [[ -x "$PLUGIN_PATH/${REGEX["$regex"]}" ]] || return 1
            REPLY="$regex"
            return 0
        fi
    done

    return 1
}

# Determines if message qualifies for spam filtering.
# This algorithm uses a leaky-bucket-like mechanism
# to prevent abuse.
#
# $1               - Nickname to check.
# returns:         - 1 if the user should be ignored for spamming.
# config: ANTISPAM - If we should time users out.
# config: ANTISPAM_TIMEOUT - Time in seconds a user must wait
#                            til they can issue another command.
# config: ANTISPAM_COUNT   - Number of requests a user gets before
#                            they are blocked for spamming.
check_spam() {
    [[ -z "$ANTISPAM" ]] && return 0

    # Allowance is the number of commands a given user
    # is allowed to invoke before they are considered abusive.
    # the last_allowed counter indicates when they last invoked
    # a given command.
    #
    # If the last_allowed was far enough in the past (ANTISPAM_TIMEOUT),
    # the user is granted an allowance.
    local allowance
    local last_allowed
    # counts down to 0
    local max_allowance=$(( ${ANTISPAM_COUNT:-3} + 1 ))

    if [[ -z "${antispam_list[$1]}" ]]; then
        allowance="$max_allowance"
        last_allowed="$SECONDS"
    else
        allowance="${antispam_list[$1]% *}"
        last_allowed="${antispam_list[$1]#* }"
    fi

    if (( allowance > 0 )); then
        allowance=$(( allowance - 1 ))
    fi

    local current_time="$SECONDS"
    local time_between_req="${ANTISPAM_TIMEOUT:-10}"
    granted_tokens=$(( ( current_time - last_allowed ) / time_between_req ))

    if (( granted_tokens > 0 )); then
        last_allowed="$current_time"
        allowance=$(( allowance + granted_tokens ))
        if (( allowance > max_allowance )); then
            allowance="$max_allowance"
        fi
    fi

    antispam_list[$1]="$allowance $last_allowed"

    if (( allowance == 0 )); then
        send_log "DEBUG" "SPAMMER -> $1"
        return 1
    else
        return 0
    fi
}

# check if nick is in ignore list
#
# $1 - nick to check
#
# returns: 1 if the user should be ignored.
# config: IGNORE - a list of nickanmes we ignore
#                  we transmute the list into a hashmap for speed.
check_ignore() {
    if [[ -n "${ignore_hash[$1]}" ]]; then
        send_log "DEBUG" "IGNORED -> $1"
        return 1
    fi
}

# check if nick is a "trusted gateway" as in a nick
# which is used by multiple individuals.
# this checks a configurable list of nicks.
#
# if the nick is not a trusted gateway, this function returns without
# doing anything
#
# Note that this function mutates message
# inputs such as user and message.
# gateway is assumed to prepend a nickname to the message
# like: <the_gateway> <user1> msg
# however: <the_gateway> user1 msg also works.
#
# $1 - the nickname
# mutates: message - New message. all the text after the first word.
# mutates: user    - The first word in the gateway's message.
# mutates: host    - A unique host for a given gateway user.
# returns: 1 if not a gateway
# config: GATEWAY  - an array of nicknames we treat as gateways
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
    local newuser="${message%% *}"
    local newmsg="${message#* }"
    # new msg without the gateway username
    # remove format reset some gateways add
    message="${newmsg#["$all_control_characters"]}"
    # delete any brackets and some special chars
    user=${newuser//[<>"$all_control_characters"]/}
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

# function to help build a plugin commandline to pass.
# Rational for --long=opts follows:
#
# --xyz=value still looks like a command line flag
# while value is trivially parsed by splitting a string by =
# --xyz *snip* value
# this reduces the complexity of parsing arguments.
# e.g.
# ```
# while (( $# > 0 )); do
#   case "$1" in
#     -m|--myflag) shift; myflag="$1" ;;
#     ...etc
#   esac
#   shift # <- VERY IMPORTANT OR YOU'LL LOOP FOREVER
# done
# ```
# vs.
# ```
# for arg; do
#   case "$arg" in
#     --myflag=*) myflag="${arg#*=}" ;;
#     ...etc
#   esac
# done
# ```
#
# in python, it's easy as well:
# ```
#   args = {}
#   for arg in argv[1:]:
#       values = arg.split('=', maxsplit=1)
#       if len(values) == 2:
#           args[values[0]] = values[1]
#   q = args.get('--message', '') # do something
# ```
#
# 1) No potential infinite loop.
# 2) Easy in all languages to parse; no need for a flag slot.
# 3) Unambiguous if a given flag has a value or is boolean.
#
# $1 - command | regexp
# $2 - cmd (hl, regexp, command prefix)
# $3 - match (regexp only)
# mutates: AREPLY - the arguments as an array.
build_cmdline() {
    local type="$1"
    local cmd="$2"
    local match="$3"
    local reply="$channel"

    # in private message, reply should be user messaging us.
    if [[ "$NICK" == "$channel" ]]; then
       reply="$user"
    # since this is assumed a channel, fetch the user's chan mode.
    else
        local cmode="${user_modes["$channel $user"]}"
        modebit_to_char "$cmode"
        cmode="$REPLY"
    fi

    # there are some common flags that exist for all types
    AREPLY=(
        --reply="$reply"
        --host="$host"
        --nick="$user" # TODO: refactor $user to nick
        --cmode="$cmode"
    )

    case "$type" in
        command)
            AREPLY+=(
                --command="$cmd"
                --message="$umsg"
            )
        ;;
        regexp)
            AREPLY+=(
                --regexp="$cmd"
                --message="$message"
                --match="$match"
            )
        ;;
    esac
}

# From main loop globals:
#  $channel - channel name
#  $host    - user's vhost
#  $user    - nickname of user
#  $umsg    - message minus command
#  $ucmd    - command name
#  $message - full message
handle_privmsg() {
    # private message to us
    if [[ "$NICK" == "$channel" ]]; then
        check_spam "$user" || return
        # most servers require this "in spirit"
        # tell them what we are
        if [[ "$message" = $'\001VERSION\001' ]]; then
            send_log "DEBUG" "CTCP VERSION -> $user <$user>"
            send_msg "NOTICE $user :"$'\001'"VERSION $VERSION"$'\001'
            return
        fi

        local cmd="$ucmd"
        # if invalid command
        if [[ -z "${COMMANDS[$ucmd]}" ]]; then
            send_msg "PRIVMSG $user :--- Invalid Command ---"
            # basically your "help" command
            cmd="${PRIVMSG_DEFAULT_CMD:-help}"
        fi

        [[ -z "${COMMANDS[$cmd]}" ]] && return
        local cmd_path="$PLUGIN_PATH/${COMMANDS[$cmd]}"
        if [[ -x "$cmd_path" ]]; then
            send_log "DEBUG" "PRIVATE COMMAND EVENT -> $cmd: $user <$user> $umsg"
            build_cmdline command "$cmd"
            "$cmd_path" "${AREPLY[@]}" | send_cmd "$user" &
        else
            send_log "ERROR" "PRIVATE COMMAND NOEXEC -> Make sure $cmd_path exists or is executable"
        fi
        return
    fi

    # highlight event in message
    if [[ "$ucmd" = ?(@)$NICK?(:|,) ]]; then
        check_spam "$user" || return
        # shellcheck disable=SC2153
        [[ -z "$HIGHLIGHT" ]] && return
        local cmd_path="$PLUGIN_PATH/$HIGHLIGHT"
        if [[ -x "$cmd_path" ]]; then
            send_log "DEBUG" "HIGHLIGHT EVENT -> $channel <$user>  $umsg"
            build_cmdline command "$cmd"
            "$cmd_path" "${AREPLY[@]}" | send_cmd "$channel" &
            return
        else
            send_log 'ERROR' "HIGHLIGHT NOEXEC -> Make sure $cmd_path exists or is executable"
            return
        fi
    fi

    # command event.
    case "${ucmd:0:1}" in ["$CMD_PREFIX"])
        local cmd="${ucmd:1}"

        [[ -z "${COMMANDS[$cmd]}" ]] && return
        local cmd_path="$PLUGIN_PATH/${COMMANDS[$cmd]}"
        if [[ -x "$cmd_path" ]]; then
            check_spam "$user" || return
            send_log "DEBUG" "COMMAND EVENT -> $cmd: $channel <$user> $umsg"
            build_cmdline command "$cmd"
            "$cmd_path" "${AREPLY[@]}" | send_cmd "$channel" &
            return
        else
            send_log 'ERROR' "COMMAND NOEXEC -> Make sure $cmd_path exists or is executable"
        fi
    esac

    # regexp check.
    if check_regexp "$message"; then
        check_spam "$user" || return
        local regex="$REPLY"

        [[ -z "${REGEX["$regex"]}" ]] && return
        local cmd_path="$PLUGIN_PATH/${REGEX["$regex"]}"
        if [[ -x "$cmd_path" ]]; then
            send_log "DEBUG" "REGEX EVENT -> $regex: $channel <$user> $message (${BASH_REMATCH[0]})"
            build_cmdline regexp "$regex" "${BASH_REMATCH[0]}"
            "$cmd_path" "${AREPLY[@]}" | send_cmd "$channel" &
            return
        else
            send_log 'ERROR' "REGEX NOEXEC -> Make sure $cmd_path exists or is executable"
        fi
    fi
}

#######################
# start communication #
#######################

# Assume ping at start
recv_ping=1

send_log "DEBUG" "COMMUNICATION START"
CAP_REQ=()
[[ -n "$SASL_PASS" ]] && CAP_REQ+=('sasl')
[[ -n "$TRACK_CHAN_MODE" ]] && CAP_REQ+=('multi-prefix')
(( ${#CAP_REQ[@]} > 0 )) && send_msg "CAP REQ :${CAP_REQ[*]}"
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
while {
    read -u 4 -r -n 1024 -t 120;
    READ_EXIT=$?
    true # Timeout is non-zero exit -gt 128
}; do
    # this allows us to fail for cases where read exits nonzero
    if (( READ_EXIT <= 128 && READ_EXIT != 0 )); then
        send_log 'CRITICAL' "READ FAILURE: $READ_EXIT"
        break
    fi
    # check for commands from the ircd
    case "$REPLY" in
        PING*) # have to reply
            send_msg "PONG ${REPLY#PING *}"
            continue
        ;;
        ERROR*) # banned?
            send_log "CRITICAL" "${REPLY#:}"
            break
        ;;
        AUTHENTICATE*) # SASL Auth
            if [[ -n "$SASL_PASS" ]]; then
                # If your base64 encoded password is longer than
                # 400byes, I got bad news for you.
                printf '%s\r\n' "AUTHENTICATE $(
                    printf '\0%s\0%s' \
                        "$NICK" "$SASL_PASS" \
                    | base64 -w 0
                )" >&3
                send_log "DEBUG" "SENT -> AUTHENTICATE <PASSWORD>"
                continue
            else
                # if we don't have an SASL pass, why did the server ask?
                send_log "CRITICAL" 'Server asked for SASL pass that is not set'
                break
            fi
        ;;
        # other unknown top level command
        [!:]*)
            send_log 'WARNING' "Server sent command we cannot handle: ($REPLY)"
            continue
        ;;
        '') # Timed out, make sure we are still connected
            if [[ -z $recv_ping ]] && (( READ_EXIT > 127 )); then
                send_log 'CRITICAL' 'Server did not respond to ping'
                break
            fi
            send_msg 'PING :'"$NICK"
            recv_ping=
            continue
        ;;
    esac

    # any message that starts with a colon and a username/server
    parse_irc "$REPLY"

    # log message
    send_log "STDOUT" ":$sender $command ${params[*]/#/arg:}"

    # handle commands here
    case $command in
        # any channel message
        PRIVMSG)
            # unpack parameters
            channel="${params[0]}"
            message="${params[1]}"

            # check if gateway nick
            trusted_gateway "$user"

            # other helpful variables
            ucmd="${message%% *}"
            umsg="${message#"$ucmd"}"
            # in case $ucmd is the only string in the message.
            # otherwise remove this argument
            umsg="${umsg# }"

            check_ignore "$user" || continue
            handle_privmsg
        ;;
        # bot ignores notices
        #NOTICE)
        #;;
        # bot was invited to channel
        # so join channel
        INVITE)
            [[ -n "$DISABLE_INVITES" ]] && continue
            # we don't accept invites from these people.
            check_ignore "$user" || continue

            # unpack params
            # :user INVITE $NICK channel
            target="${params[0]}"
            channel="${params[1]}"
            # protect from potential bad index access
            # make sure target is us.
            [[ -z "$channel" && "$target" = "$NICK" ]] && continue
            send_cmd <<< ":jd ${INVITE_DELAY:-2} $channel" &
            send_log "INVITE" "<$user> $channel "
            if [[ -n "$INVITE_FILE" &&
                  "${invites[$channel]}" != 1 ]]
            then
                echo1 "$channel" >> "$INVITE_FILE"
                invites[$channel]=1
            fi
        ;;
        # when the bot joins a channel
        JOIN)
            if [[ "$user" = "$NICK" ]]; then
                channel="${params[0]}"
                # channel joined add to list or channels
                CHANNELS+=("$channel")
                send_log "JOIN" "$channel"
            else
                unset user_modes["$channel $user"]
            fi
        ;;
        # when the bot leaves a channel
        PART)
            channel="${params[0]}"
            # protect from potential bad index access
            [[ -z "$channel" ]] && continue
            if [[ "$user" = "$NICK" ]]; then
                for i in "${!CHANNELS[@]}"; do
                    if [[ "${CHANNELS[$i]}" = "$channel" ]]; then
                        unset CHANNELS["$i"]
                        if [[ -n "${invites[$channel]}" ]]; then
                            unset invites["$channel"]
                            printf '%s\n' "${!invites[@]}" \
                                > "$INVITE_FILE"
                        fi
                    fi
                done
                send_log "PART" "$channel"
            else
                unset user_modes["$channel $user"]
            fi
        ;;
        # only way for the bot to be removed
        # from a channel, other than config reload
        KICK)
            # :prefix KICK #chan target_user :reason
            channel="${params[0]}"
            target="${params[1]}"
            why="${params[2]}"
            why="${why:-'No Reason Given'}"
            # protect from potential bad index access
            [[ -z "$channel" ]] && continue
            if [[ "$target" = "$NICK" ]]; then
                for i in "${!CHANNELS[@]}"; do
                    if [[ "${CHANNELS[$i]}" = "$channel" ]]; then
                        unset CHANNELS["$i"]
                        if [[ -n "${invites[$channel]}" ]]; then
                            unset invites["$channel"]
                            printf '%s\n' "${!invites[@]}" \
                                > "$INVITE_FILE"
                        fi
                    fi
                done
                send_log "KICK" "<$user> $channel [Reason: $why]"
            else
                unset user_modes["$channel $user"]
            fi
        ;;
        NICK)
            # :prefix(us) NICK new_nick [ unused ]
            new_nick="${params[0]}"
            if [[ "$user" == "$NICK" ]]; then
                [[ -z "$orig_nick" ]] && orig_nick="$NICK"
                NICK="${new_nick}"
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
        # we need to know what modes this server supports to properly
        # parse MODE command output
        005)
            # :prefix 005 $NICK [ KEY=VALUE ... ] :are supported by this server
            rest=("${params[@]:1:${#params[@]}-1}")
            parse_005 "${rest[@]}"
        ;;
        # NAMES reply
        353)
            # :prefix 353 $NICK {'@'|'='} #chan :[~&@%+]nick [ [~&@%+]nick ] ...
            [[ -z "${TRACK_CHAN_MODE}" ]] && continue
            channel="${params[2]}"
            message="${params[3]}"
            parse_353 "$channel" "$message"
        ;;
        # This mode depends on multi-prefix which we only ask for
        # if TRACK_CHAN_MODE is enabled.
        MODE)
            [[ -z "${TRACK_CHAN_MODE}" ]] && continue
            [[ "$user" == "$NICK" ]] && continue
            channel="${params[0]}"
            rest=("${params[@]:1}")
            parse_mode "$channel" "${rest[@]}"
        ;;
        # PASS command failed
        464)
            send_log 'CRITICAL' 'INVALID PASSWORD'
            break
        ;;
        # banned from server.
        465)
            send_log 'CRITICAL' 'YOU ARE BANNED'
            break
        ;;
        # the nickname is "invalid" for reasons or is empty somehow.
        431|432)
            # :server 432 $NICK :reason
            why="${params[*]}"
            send_log 'CRITICAL' "$why"
            break
        ;;
        # Nickname is already in use/collision
        # add _ and try the new nick
        433|436)

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
        # SASL specific
        CAP)
            # :server CAP $NICK ACK :sasl
            ack="${params[1]}"
            # We only ever ask for sasl
            message="${params[2]}"
            parse_cap "$ack" "$message" || break
        ;;
        # SASL status commands
        903)
            send_msg "CAP END"
        ;;
        902|904|905|906)
            message="${params[2]}"
            send_msg "CAP END"
            send_log 'CRITICAL' "$message"
            break
        ;;
        PONG)
            recv_ping=1
            send_log 'DEBUG' 'RECV -> PONG'
        ;;
        # not an official command, this is for getting
        # key stateful variable from the bot for mock testing
        __DEBUG)
            # disable this if not in mock testing mode
            [[ -z "$MOCK_CONN_TEST" ]] && continue
            channel="${params[0]}"
            message="${params[1]}"
            # mock test trusted_gateway code
            trusted_gateway "$user"

            case $message in
                channels)  echo1 "${CHANNELS[*]}" >&3 ;;
                nickname)  echo1 "$NICK"    >&3 ;;
                nickparse) echo1 "$user"    >&3 ;;
                hostparse) echo1 "$host"    >&3 ;;
                chanparse) echo1 "$channel" >&3 ;;
                msgparse)  echo1 "$message" >&3 ;;
                chanmode)
                    _umode="${user_modes["$channel ${params[2]}"]}"
                    modebit_to_char "$_umode"
                    echo1 "$REPLY" >&3
                ;;
                '<'*'> nickparse') echo1 "$message" >&3 ;;
                *)         echo1 "${params[*]}" >&3 ;;
            esac
        ;;
    esac
done
send_msg "QUIT :bye"
send_log 'CRITICAL' 'Exited Event loop; timed out or disconnected.'
exit_failure
