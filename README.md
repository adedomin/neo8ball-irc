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
    ExecReload=/bin/kill -HUP \$MAINPID
    Restart=on-failure

    [Install]
    WantedBy=multi-user.target

Developing New Plugins
-----------------------

neo8ball by default only responds to CTCP VERSION messages.
To make the bot do anything else, you must develop your own plugins.

Below is a guide which explains how your plugins can communicate with neo8ball.

### Arguments

Pugins receive five (six for regexp) arguments:

  1. The channel the message came from; (ALT) the user the message came from if it is a private message event.
  2. User's vhost (use to be date and time)
  3. The nickname the message came from
  4. The message itself
  5. name of the command it matched; (ALT) the library path if highlight; (ALT2) the string that matched a regex event
  6. If event is a regexp one, the sixth argument is the matched text in the regexp.

### Interacting with the channels

Plugins communicate with neo8ball through stdout.
Plugins can write to stderr for logging, however it is recommended
that they use the log command instead.
Plugins must print out a command string using the below syntax:

    :j #chan          - join a channel
    :j #chan,#..      - join multiple channels
    :l #chan          - leave a channel
    :l #chan,#..      - leave multiple channels
    :m #chan message  - send message to channel or user
    :mn #chan message - send notice to channel or user
    :n new_nick       - change nick (might be removed)
    :l[ewid] log_msg  - send a string to the (e)rror|(w)arn|(i)nfo|(d)ebug log
    :r anything       - send raw irc command; e.g. PRIVMSG #chan :hi

All commands start with a colon (:), the command letter(s) and the arguments.
All the commands that take multi-space arguments already have the colon appended to the front of them, except for raw commands.

So do not do something like:

    :m #chan :this is a multi-space message.

just do:

    :m #chan this is a multi-space message.

### State

State, and mutexes are ultimately the plugin's responsibility;
only a temporary path and environment variables are provided by neo8ball to plugins.
The environment variable, PLUGIN_TEMP, will be populated with the temporary directory.
A plugin can use this path to store temporary state.
This directory is removed when neo8ball stops.

Configurations, such as API keys, can be provided as exported environment variables.
Simply add a line like: `export PLUGIN_VARIABLE_NAME=value` in config.sh.
