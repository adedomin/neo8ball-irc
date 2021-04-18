# shellcheck disable=2034
# Your Nickname
# Username is also set to this
# This value is used for SASL as well
NICK="neo8ball"
# Server password (NOT SASL)
# leave blank to disable
PASS=
# SASL PLAIN
# Note, Depends on a `base64` binary
# if your password is insanely long (b64(pass) > 399B)
# This won't work
# You likely don't need nickserv if you have this
# leave blank to disable this
SASL_PASS=
# NickServ password
# leave blank to disable this
NICKSERV=
# irc server
SERVER="irc.rizon.net"
# channels to join
CHANNELS=("#prussian")
# TODO: not implemented
# CHANNEL_BLACKLIST=("#badchan")
# set to non-empty to disable automatic invite handling
DISABLE_INVITES=
# supplimentary channels to join from file
INVITE_FILE="/tmp/invite-channel-list"
# delay joining on invite to prevent potential flood kicks (rizon)
# number is in seconds, can be fractional.
INVITE_DELAY=3

# This option enables mode tracking for usernames and passes
# the mode as the 7th argument
#
# leave this as blank to disable
# this command spams the NAMES command everytime a MODE is set
# be wary of that.
TRACK_CHAN_MODE=1

# port number
PORT="6697"
# use tls
# set to blank to disable
TLS=yes
# verify trust using system trust store
VERIFY_TLS=yes
# verify trust using given cert(s)
# VERIFY_TLS_FILE=/path/to/cert/bundle

# IPC related files will use this root
temp_dir=/tmp

# LOGGING
# log levels
# 1 - DEBUG
# 2 - INFO
# 3 - WARN
# 4 - ERR/CRIT
LOG_LEVEL=1
# leave blank to not write messages to stdout
LOG_STDOUT=y

# dirname for lib/plugin defaults
# BASH_SOURCE[1] = the original script that sourced this configuration.
case "${BASH_SOURCE[1]}" in
    */*) BASE_PATH="${BASH_SOURCE[1]%/*}" ;;
    *) BASE_PATH='./' ;;
esac

LIB_PATH="${BASE_PATH}/lib/"
# let other programs know where helpers are.
export LIB_PATH

PLUGIN_PATH="${BASE_PATH}/plugins/"
export PLUGIN_PATH

# allows you to set a global useragent for curl using a .curlrc
# as the same dir the config is in
export CURL_HOME="${BASE_PATH}"

# on highlight, call the following script/s
HIGHLIGHT="8ball.sh"
# default command to execute if no valid command matches
# in a private message context
PRIVMSG_DEFAULT_CMD='help'

# prefix that commands should start with
CMD_PREFIX=".,!"
declare -gA COMMANDS
# command names should be what to test for
# avoid adding prefixes like .help
# use as follows:
#  ['one-word-command-string']='the command to execute'
COMMANDS=(
["8"]="8ball.sh"
["8ball"]="8ball.sh"
["define"]="define.sh"
["decide"]="8ball.sh"
["duck"]="duckduckgo.py"
["ddg"]="duckduckgo.py"
["g"]="duckduckgo.py"
["help"]="help.sh"
["bots"]="bots.sh"
["source"]="bots.sh"
#["w"]="weather.sh"
["owm"]="weather.sh"
["weather"]="weather.sh"
["nws"]="nws.sh"
["npm"]="npm.sh"
["mdn"]="mdn.sh"
["wiki"]="wikipedia.sh"
["yt"]="youtube.sh"
["you"]="youtube.sh"
["youtube"]="youtube.sh"
["u"]="urbandict.sh"
["urb"]="urbandict.sh"
["urban"]="urbandict.sh"
["bible"]="bible.sh"
["quran"]="bible.sh"
["fap"]="fap.sh"
["gay"]="fap.sh"
["straight"]="fap.sh"
["moose"]="moose.sh"
["vote"]="vote.sh"
["yes"]="vote.sh"
["no"]="vote.sh"
["standings"]="vote.sh"
["mlb"]="mlb.py"
["twit"]="twitter.sh"
["twitter"]="twitter.sh"
["r"]="rfc.sh"
["rfc"]="rfc.sh"
["what_is_my_mode"]="mode-test.sh"
)

declare -gA REGEX
# regex patterns
# if you need more fine grained control
# uses bash regexp language
# use as follows:
#  ['YOUR REGEXP HERE']='the command to execute'
REGEX=(
['https?://twitter.com/[^/]+/status/[0-9]+|t.co/[a-zA-Z0-9]+']='twitter.sh'
['youtube.com|youtu.be']='youtube.sh'
# literally anything can be a url nowadays
['(https?)://[^ ]+']='pagetitle.py'
['^moose']='moose.sh'
)

# bash associative arrays are not strictly ordered
REGEX_ORDERED=(
'https?://twitter.com/[^/]+/status/[0-9]+|t.co/[a-zA-Z0-9]+'
'youtube.com|youtu.be'
'(https?)://[^ ]+'
'^moose'
)

# list of nicks to ignore from, such as other bots
IGNORE=(
)

# list of nicks considered to be trusted gateways
# gateways are shared nicknames that prepend user info
# to the front of the message in the format like <gateway> <user> msg
# for an example of a gateway, see teleirc on npm which is a 
# telegram <-> IRC gateway bot
GATEWAY=(
)

# anti spam feature
# prevent users from abusing your bot
# set to blank to disable
ANTISPAM=yes
# a new command allowance is given every x amount of seconds
# time in seconds to grant an allowance
ANTISPAM_TIMEOUT=10
# max number of commands a user gets in a time period
ANTISPAM_COUNT=3

## variables for plugins ##

# comment out if you don't want
# to use OpenWeatherMap plugin
export OWM_KEY="your owm key"

# your persistant storage here,
# comment out to disabable weatherdb.sh
export PERSIST_LOC="/tmp"

# for youtube.sh
#export YOUTUBE_KEY="your youtube api key"

# you have to generate bible_db yourself, see create-db.sh in ./static
#export BIBLE_DB="$(dirname "$0")/static/kjbible-quran.db"
export BIBLE_SOURCE="$(dirname "$0")/static/king-james.txt"
export QURAN_SOURCE="$(dirname "$0")/static/quran-allah-ver.txt"

# newline separated channels to disable pagetitle plugin in
# RESTRICTIONS:
# be careful to remove trailing/leading spaces from channels
# has to be a string due to bash EXPORT restrictions
export PAGETITLE_IGNORE='
#nopagetitle
'

# newline separated channels to disable the
# youtube regexp match mode
# same issues as with PAGETITLE_IGNORE
export YOUTUBE_IGNORE='
#noyoutuberegexp
'

# list of channels to not print moose in
# some channels may insta ban if multiple lines are written rapidly
# same issues as with PAGETITLE_IGNORE
export MOOSE_IGNORE="
#nomoose
"
# sleep timeout to prevent moose spam
export MOOSE_SLEEP_TIMER='10s'
# delay in seconds (supports decimal assuming gnu sleep)
export MOOSE_OUTPUT_DELAY='0.3s'

# rate to poll following MLB games
# in seconds or whatever timespec that the sleep command takes
export MLB_POLL_RATE=90

# the following are twitter consumer key and secret for the twitter plugin
#export TWITTER_KEY=your-key-here
#export TWITTER_SECRET=your-key-here

# moved common functions in the lib path.
# you can store them here or add your own below as before
. "$LIB_PATH/common-functions.sh"

# DO NOT ENABLE THIS UNLESS YOU'RE TESTING
#MOCK_CONN_TEST=yes
