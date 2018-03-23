Neo 8ball
=========

Usage
-----

    usage: ./ircbot.sh [-c config]

        -c --config=path    A config file
        -o --log-out=file   A file to log to instead of stdout.
        -h --help           This message

    If no configuration path is found or CONFIG_PATH is not set,
    ircbot will assume the configuration is in the same directory
    as the script.

    For testing, you can set MOCK_CONN_TEST=<anything>

Configure
---------

Edit the config.sh file and save it where you deem approprate.
Make sure to use the -c or --config flag if you don't leave the configuration in the default location--same directory as the ircbot.sh script.

Many of the plugins which come with neo8ball require API keys or variable information.
config.sh describes these variables for all the built-in plugins

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
