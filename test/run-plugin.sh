#!/bin/bash
. "${CONFIG:-${BASH_SOURCE[0]%/*}/../config.sh}"
LIB_PATH='./lib'
. ./lib/common-functions.sh
PLUGIN_PATH='./plugins'
exec "${PLUGIN_PATH}/${COMMANDS["$1"]}" "##test_channel" "test_user_vhost" "test_user" "$2" "$1"
