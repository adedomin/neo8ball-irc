#!/usr/bin/env bash
echo -e ":m $1 \0028ball\002 .8ball <question>?|<choice1> or <choice2>? ::" \
    "\002Web Search\002 .ddg <query> ::" \
    "\002Weather\002 .owm <location> ::" \
    "\002Set Location\002 .location <location> ::" \
    "\002Vidme\002 .v <query> ::" \
    "\002NWS METAR OBV\002 .nws <station> ::" \
    "\002Set Station\002 .nwsd <station> ::" \
    "\002NPM Search\002 .npm <query> ::" \
    "\002Wikipedia Search\002 .wiki <query> ::" \
    "\002Reddit\002 .reddit [sub] [new|hot|best|top|controversial] ::" \
    "\002Youtube\002 .yt <query>" \
