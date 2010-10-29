# Location of curl on your system ( http://curl.haxx.se/ )
CURL=/usr/bin/curl

# Location of XMLStarlet on your system ( http://xmlstar.sourceforge.net/ )
XML=/usr/local/bin/xml

# Location of URLencode script ( http://www.shelldorado.com/scripts/cmds/urlencode )
URLENCODE="`dirname $0`/lib/urlencode"

# Change to something other than YES to leave behind temporary files
REMOVEFILES="YES"

# Set to non-blank to spit out more information related to errors encountered
VERBOSE=""

#Set the environment variable CNBASE to change the root CN BaseURL
if [ -z $CNBASE ]; then
  CNBASE="http://cn-dev.dataone.org/cn"
fi


REGISTRY_DOC="/tmp/d1_registry.xml"
TEMPOUTPUT="/tmp/d1_test_output"
DEFAULTGETOUTPUT="/tmp/d1_get_output"

NS_OBJECTLIST="http://dataone.org/service/types/ObjectList/0.5"

#===============
# Text color variables
txtund=$(tput sgr 0 1)    # Underline
txtbld=$(tput bold)       # Bold
txtred=$(tput setaf 1)    # Red
txtgrn=$(tput setaf 2)    # Green
txtylw=$(tput setaf 3)    # Yellow
txtblu=$(tput setaf 4)    # Blue
txtpur=$(tput setaf 5)    # Purple
txtcyn=$(tput setaf 6)    # Cyan
txtwht=$(tput setaf 7)    # White
txtrst=$(tput sgr0)       # Text reset
#===============


function cleanup_temp_files(){
  if [ $REMOVEFILES="YES" ]; then
    rm -f $REGISTRY_DOC
    rm -f $TEMPOUTPUT
  fi
}

function load_registry_doc(){
  #Loads a node registry doc from a coordinating node
  if [ ! -e $REGISTRY_DOC ]; then
    `$CURL -s -o $REGISTRY_DOC "$CNBASE/node"`
  fi
}


function list_nodes(){
  #Set a space delimited list of node identifiers from the registry
  load_registry_doc
  NODELIST=`cat $REGISTRY_DOC | $XML sel -T -t -m "//node/identifier" -v . -n`
}


function ping_node(){
  #Check if node is alive 
  get_node_baseurl $1
  HTTPCODE=`curl -s -w "%{http_code}" -o $TEMPOUTPUT $BASEURL`
  if [ $HTTPCODE = "200" ]; then
    printf "${txtgrn}OK${txtrst} \tCODE=$HTTPCODE \tID=$1 \tURL=$BASEURL \n"
  else
    printf "${txtred}FAIL \tCODE=$HTTPCODE \tID=$1 \tURL=$BASEURL${txtrst} \n"
    if [ ! -z $VERBOSE ]; then
      echo "================="
      cat $TEMPOUTPUT
      echo "================="
    fi
  fi
}


function get_node_baseurl(){
  #Set the BASEURL variable given a node identifier
  load_registry_doc
  BASEURL=`cat $REGISTRY_DOC | $XML sel -T -t \
    -m "//node/identifier[text()='$1']" -v "../baseURL"`
}


function get_object_list(){
  # $1 = baseURL of node to work with
  URL="$BASEURL/object"
  $CURL -s -H "Accept: text/xml" -o $TEMPOUTPUT $URL
  OBJECTLIST=`cat $TEMPOUTPUT | $XML sel -N d1=$NS_OBJECTLIST \
    -t -m "//d1:objectList" \
    -o "START=" -v "@start" -o " COUNT=" -v "@count" -o " TOTAL=" -v "@total" \
    -n -m "//identifier" -v "." -o " " -v "../size" -o " " \
    -v "../objectFormat" -n` 
}


function resolve_object_nodes(){
  # sets NODEIDS = an array of node identifiers holding the specified object
  #$1 = identifier of object to resolve
 
  IDENTIFIER="`echo $1 | $URLENCODE`"
  URL="$CNBASE/resolve/$IDENTIFIER"
  $CURL -s -H "Accept: text/xml" -o $TEMPOUTPUT $URL
  NODEIDS=( `cat $TEMPOUTPUT | $XML sel -T -t \
    -m "//objectLocation/nodeIdentifier" -v . -n` )
  return 0
}


function get_system_metadata(){
  # loads system metadata for object with identifier $1 to $TEMPOUTPUT
  IDENTIFIER="`echo $1 | $URLENCODE`"
  URL="$CNBASE/meta/$IDENTIFIER"
  $CURL -s -H "Accept: text/xml" $URL | $XML fo -s 2 > $TEMPOUTPUT
}


function get_object(){
  #retrieves object with id $1 from the preferred node and stores it to $2
  TARGET=$2
  if [ -z ${TARGET} ]; then
    TARGET=$DEFAULTGETOUTPUT
  fi 
  resolve_object_nodes $1
  get_node_baseurl ${NODEIDS[0]}
  URL="${BASEURL}object/${IDENTIFIER}"
  echo $URL
  
  curl $URL > $TARGET
  echo "Output saved to $TARGET"
}
