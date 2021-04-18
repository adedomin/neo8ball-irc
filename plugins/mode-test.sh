#!/bin/sh
for arg; do
    case "$arg" in
        --nick=*)    nick="${arg#*=}" ;;
        --cmode=*)   mode="${arg#*=}" ;;
    esac
done

printf ':r %s: your mode is <%s>\n' "$nick" "$mode"
