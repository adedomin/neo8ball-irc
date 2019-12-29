#!/bin/bash
. "${CONFIG:-${BASH_SOURCE[0]%/*}/../config.sh}"
exec "${LIB_PATH}/${COMMANDS["$1"]}" "##test_channel" "test_user_vhost" "test_user" "$2" "$1"
