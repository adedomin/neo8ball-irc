#!/usr/bin/env bash
for arg; do
    case "$arg" in
        --nick=*)    nick="${arg#*=}" ;;
        --command=*) command="${arg#*=}" ;;
    esac
done

echo ":mn $nick Plugin ((( "$'\002'"$command"$'\002'" ))) is currently disabled."
