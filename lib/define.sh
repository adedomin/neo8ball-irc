#!/bin/bash

 echo "http://www.dictionary.com/browse/$1" |
 wget -O- -i- --quiet | 
 hxnormalize -x 2>/dev/null | 
 hxselect -i "div.def-set" 2>/dev/null |  
 lynx -stdin -dump 2>/dev/null |
 xargs 2>/dev/null |
 sed $'s/1\./\\\n1./g' |
 awk -F '1.|4.' '{print $2}' |
 tail -n +2
