# nickname, also username
NICK="neo8ball2"
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

## DECLARE IRC events here ##

LIB_PATH="$(dirname "$0")/"

# on highlight, call the following script/s
HIGHLIGHT="lib/8ball.sh"
# on private message, as in query
PRIVATE="lib/invite.sh"
# on join
JOINING=

# prefix that commands should start with
CMD_PREFIX=".,!"
declare -A COMMANDS
# command names should be what to test for
# avoid adding prefixes like .help
COMMANDS=(
["8"]="lib/8ball.sh" 
["8ball"]="lib/8ball.sh" 
["decide"]="lib/8ball.sh" 
["duck"]="lib/search.sh" 
["ddg"]="lib/search.sh" 
["g"]="lib/search.sh"
["help"]="lib/help.sh"
["bots"]="lib/bots.sh"
["v"]="lib/vidme.sh"
["vid"]="lib/vidme.sh"
["vidme"]="lib/vidme.sh"
["w"]="lib/weather.sh"
["owm"]="lib/weather.sh"
["weather"]="lib/weather.sh"
)

# regex patterns
# if you need more fine grained control
# uses bash regex language
declare -A REGEX
#REGEX=(["^\.bots"]="test/bots.sh")
