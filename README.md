Neo 8ball
=========

Usage
-----

run:

    ./ircbot.sh & disown

configure:

    vim ./config.sh

For OpenWeatherMap, you need an API key; you can set it in the config.
Make sure it is exported.
By default the variable name is OWM_KEY.

For default weather location persistance and .nws search you need PERSIST_LOC defined in your environment.
You can set it in the config.
Make sure this value is exported

Example systemd Service
-----------------------

    [Unit]
    Description=neo8ball irc bot

    [Service]
    User=bots
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
