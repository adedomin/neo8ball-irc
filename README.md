Neo 8ball
=========

Usage
-----

    usage: ./ircbot.sh [-c config] [-o logfile] [-t]

        -t --timestamp      Timestamp logs using iso-8601.
        -c --config=file    A neo8ball config.sh
        -o --log-out=file   A file to log to instead of stdout.
        -h --help           This message.

    If no configuration path is found or CONFIG_PATH is not set,
    ircbot will assume the configuration is in the same directory
    as the script.

    For testing, you can set MOCK_CONN_TEST=<anything>

Configure
---------

Edit the config.sh file and save it where you deem appropriate.
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

Plugins receive a series of plugins which you can parse as "--key=value" pairs.
--key= was chosen because it is a long option, but it is easy to parse without using a temporary variable as some kind of flag slot or a library argument parser.
This breaks the old way this worked, which used specific positions with semantic values.

Pugins currently receive the following arguments:

  1. `--reply='#channel or nickname'` This where the message originated, unless it is a private message, then it is the nickname of the sender.
  2. `--host='the @ part in a prefix'` this is the sender's host.
  3. `--nick=nickname_of_sender` this is the sender's nick.
  4. `--cmode=[qaohv]` a single letter representing the highest mode the sending user has.
  5. `--message='full user message'` the message.
  
Depending if the command was invoked as a command, e.g. `.some_command`, or as a regexp match depends what the remaining arguments are.

#### Command Specific Arguments

  1. `--command=some_command` the name of the command that invoked this plugin, stripped from `--message`.

#### RegExp Specific Arguments

  1. `--regexp=the_regexp` the regexp that matched the `--message`
  2. `--match=matched_text` the text matched by the regexp in `--message`.

### Interacting with the channels

Plugins communicate with neo8ball through stdout.
Plugins can write to stderr for logging, however it is recommended
that they use the log command instead.
Plugins must print out a command string using the below syntax:

    :j #chan          - Join a channel.
    :j #chan,#..      - Join multiple channels.
    :l #chan          - Leave a channel.
    :l #chan,#..      - Leave multiple channels.
    :m #chan message  - Send message to channel or user.
    :mn #chan message - Send notice to channel or user.
    :n new_nick       - Change nick (might be removed).
    :l[ewid] log_msg  - Send a string to the (e)rror|(w)arn|(i)nfo|(d)ebug log.
    :r message        - Replies to the channel where the message came from.
    :raw raw irc msg  - Send raw irc command; e.g. ':raw PRIVMSG #chan :hi'

All commands start with a colon (:), the command letter(s) and the arguments.
All the commands that take multi-space arguments already have the colon appended to the front of them, except for raw commands.

So do not do something like:

    :m #chan :this is a multi-space message.

just do:

    :m #chan this is a multi-space message.

Note that there can only be one space between arguments. Any more will be interpreted as part of the argument. e.g.

    :m #channel    leading spaces will be output to irc.

### State

State, and mutexes are ultimately the *plugin's responsibility*;
only a temporary path and environment variables are provided by neo8ball to plugins.
The environment variable, `PLUGIN_TEMP`, will be populated with the temporary directory.
A plugin can use this path to store temporary state.
This directory is removed when neo8ball stops.

Configurations, such as API keys, can be provided as exported environment variables.
Simply add a line like: `export PLUGIN_VARIABLE_NAME=value` in config.sh.
