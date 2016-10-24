#!/usr/bin/env bash
read -r cmd chan <<< "$4"

case $cmd in
    invite|INVITE)
        echo ":j $chan"
    ;;
    leave|LEAVE)
        echo ":l $chan"
    ;;
esac
