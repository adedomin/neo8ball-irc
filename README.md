Bash ircbot framework
=====================

Depends on ncat.

Usage
-----

check out the config.sh for configuring the tool
The tool is designed to call your external shell scripts or binaries based on events in irc.

### Arguments

The external programs recieve five arguments.

  1. the channel the message came from (same as 3 in PM)
  2. date and time
  3. the user the message came from
  4. the message itself
  5. the path to the served webroot

note that for valid command matches, argument 4 is the message without the command string attached to it.

### Interacting with the channels

In these external programs you must print out a command string using the below syntax:

	:j #chan         - join a channel
	:l #chan [msg]   - leave a channel
	:m #chan message - send message to channel
	:r anything      - send raw irc command
    :w #chan filepath - outputs a link to filepath

All commands start with a colon (:) and the arguments.
All the commands that take multiline arguments alreaady have the colon prepended to them, except for raw commads.

### Events

  1. private message
    * this is when a user pm's the bot
  2. highlight
    * this is when the bot's name is mentioned in the msg
  3. commands
    * a message starts with a command string eith the appropriate prefix
  4. other/regex
    * if none of the above help, you can use bash regular expressions to create custom alerts

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
