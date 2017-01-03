#!/usr/bin/env bash
URI='http://www.dictionary.com/browse/'

RES=$(curl "${URI}${4}" 2>/dev/null | \
 hxnormalize -x 2>/dev/null | \
 hxselect -i "div.def-set" 2>/dev/null | \
 lynx -stdin -dump 2>/dev/null | \
 sed $'s/1\./\\\n1./g' | \
 awk -F '1.|4.' '{print $2}' | \
 tail -n +2
)

IFS=$'\n' 
for res in $RES; do
    echo ":m $1 $res"
done
