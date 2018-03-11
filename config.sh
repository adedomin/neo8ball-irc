# shellcheck disable=2034
# nickname, also username
NICK="neo8ball"
# NickServ password
# blank for unreg
NICKSERV=
# irc server
SERVER="irc.rizon.net"
# channels to join
CHANNELS=("#prussian" "#prussian2")
# supplimentary channels to join from file
INVITE_FILE="/tmp/invite-channel-list"

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

# read notice messages? spec say do not
READ_NOTICE=

# LOGGING
# log levels
# 1 - DEBUG
# 2 - INFO
# 3 - WARN
# 4 - ERR/CRIT
LOG_LEVEL=1
# leave blank to not write messages to stdout
LOG_STDOUT=

## DECLARE IRC events here ##

LIB_PATH="$(dirname "$0")/lib/"
# let other programs know where plugins are.
export LIB_PATH

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
COMMANDS=(
["8"]="8ball.sh" 
["8ball"]="8ball.sh" 
["define"]="define.sh"
["decide"]="8ball.sh" 
["duck"]="search.sh" 
["ddg"]="search.sh" 
["g"]="search.sh"
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
["mlb"]="mlb.sh"
["twit"]="twitter.sh"
["twitter"]="twitter.sh"
["r"]="rfc.sh"
["rfc"]="rfc.sh"
)

# regex patterns
# if you need more fine grained control
# uses bash regex language
#
# NOTE: as of the latest version
# regex is changed to an array
# this is to ensure strict ordering.
# the program expects the array to order
# them in the format of
# 'REGEX' 'command'
# or in other words, every even index (first index is 0) 
# should be a regex and every uneven index should be 
# the plugin to execute
REGEX=(
'youtube.com|youtu.be' 'youtube.sh'
# literally anything can be a url nowadays
'(https?)://[^ ]+' 'pagetitle.sh'
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

# time in minutes to check for closed socket
# this is applicable if you use ncat
HALFCLOSE_CHECK=3

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

# list of channels to not print moose in
# some channels may insta ban if multiple lines are written rapidly
# has to be string due to bash export limitations
export MOOSE_IGNORE="
#nomoose
"
# sleep timeout to prevent moose spam
export MOOSE_SLEEP_TIMER='5s'

# MS Cognitive Services Computer Vision API (describe)
# for enhanced insight on images in lib/pagetitle.sh
export MS_COG_SERV='https://westcentralus.api.cognitive.microsoft.com/vision/v1.0/describe'
# keep this commented out if you want to disable this feature
#export MS_COG_KEY='api key here'

# Uncomment to disable pagetitle.sh "File" reports.
#export PAGETITLE_DISABLE_FILE=1

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
