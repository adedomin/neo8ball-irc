Neo 8ball
=========

Usage
-----

run:

    ./ircbot.sh >/dev/null 2>/dev/null & disown

configure:

    vim ./config.sh

For weather, you need an API key; if you use systemd service, you can set the OWM_KEY variable there. e.g.

    Environment="OWM_KEY=<some-key-goes-here>"

For default weather location persistance and .nws search you need the following env variable

    Environment="PERSIST_LOC=/home/neo8ball/.local/var/db/"

In your 8ball.service file.
If you do not do this, you need to maintain another method for making these values available to your bot.
You can likely include it in your config file and export the variable.

Example systemd Service
-----------------------

    [Unit]
    Description=neo8ball irc bot

    [Service]
    User=bots
    Environment="OWM_KEY=some key"
    Environment="PERSIST_LOC=/home/bots/.local/var/db/"
    ExecStart=/bin/bash /home/bots/src/neo8ball-irc/ircbot.sh
    ExecReload=/bin/kill -HUP $MAINPID
    Restart=on-failure

    [Install]
    WantedBy=multi-user.target

Licence
-------

Copyright 2016 prussian <generalunrest@airmail.cc>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

  <http://www.apache.org/licenses/LICENSE-2.0>

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
