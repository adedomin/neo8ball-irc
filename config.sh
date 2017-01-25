# nickname, also username
NICK="neo8ball"
# NickServ password
# blank for unreg
NICKSERV=
# irc server
SERVER="irc.rizon.net"
# channels to join
CHANNELS=("#prussian")

# port number
PORT="6697"
# use tls
# set to blank to disable
TLS=yes

# IPC related files will use this root
temp_dir=/tmp

# read notice messages? spec say do not
READ_NOTICE=

# LOGGING
# leave blank to not write messages to stdout
LOG_STDOUT=yes
# leave blank to ignore sent and nick changes
LOG_INFO=yes

## DECLARE IRC events here ##

LIB_PATH="$(dirname "$0")/lib/"

# on highlight, call the following script/s
HIGHLIGHT="8ball.sh"
# on private message, as in query
PRIVATE="invite.sh"
# on join
JOINING=

# prefix that commands should start with
CMD_PREFIX=".,!"
declare -A COMMANDS
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
["v"]="vidme.sh"
["vid"]="vidme.sh"
["vidme"]="vidme.sh"
#["w"]="weather.sh"
["owm"]="weather.sh"
["weather"]="weather.sh"
["wd"]="weatherdb.sh"
["location"]="weatherdb.sh"
["nws"]="nws.sh"
["nwsl"]="weatherdb.sh"
["nwsd"]="weatherdb.sh"
["npm"]="npm.sh"
["wiki"]="wikipedia.sh"
)

# regex patterns
# if you need more fine grained control
# uses bash regex language
declare -A REGEX
#REGEX=(["^\.bots"]="test/bots.sh")
