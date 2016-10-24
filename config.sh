# nickname, also username
NICK="neo8ball"
# irc server
SERVER="irc.rizon.net"
# channels to join
CHANNELS=("#/cum/" "#trollhour" "#ghetty")

# port number
PORT="6697"
# use tls
# set to blank to disable
TLS=a

# IPC related files will use this root
temp_dir=/tmp

# read notice messages? spec say do not
READ_NOTICE=

## WEB STUFF - NOT IMPL ##
# some bots may need to share/create files
# below settings control web configuration

# directory to serve
WEB_ROOT="$PWD/web"
WEB_PORT=18080
# hostname:port the content could be accessed at
DOMAIN="http://home.dedominic.pw:$WEB_PORT"

## DECLARE IRC events here ##

# on highlight, call the following script/s
HIGHLIGHT="./lib/decide.sh"
# on private message, as in query
PRIVATE="./lib/invite.sh"
# on join
JOINING=

# prefix that commands should start with
CMD_PREFIX=".,!"
declare -A COMMANDS
# command names should be what to test for
# avoid adding prefixes like .help
COMMANDS=(["say"]="./lib/say.sh" ["8"]="./lib/8ball.sh" ["8ball"]="./lib/8ball.sh" ["decide"]="./lib/decide.sh" ["duck"]="./lib/search.sh" ["g"]="./lib/search.sh")

# regex patterns
# if you need more fine grained control
# uses bash regex language
declare -A REGEX
#REGEX=(["^\.bots"]="./test/bots.sh")
