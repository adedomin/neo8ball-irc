#!/usr/bin/env bash
echo -e ":m $1 \0028ball\002 .8ball <question>?|<choice1> or <choice2>? :: \002Web Search\002 .ddg <query> :: \002Weather\002 .owm <location> :: \002Set Location\002 .location <location> :: \002Vidme\002 .v <query> :: \002NWS METAR OBV\002 .nws <station> :: \002Set Station\002 .nwsd <station>"
