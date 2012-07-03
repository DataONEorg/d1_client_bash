#List of known CNs
COORDINATING_NODES=( "http://cn-dev.dataone.org/cn" \
                     "http://cn-dev2.dataone.org/cn" \
                     "http://cn-unm-1.dataone.org/cn" \
                     "http://cn-ucsb-1.dataone.org/cn" \
                     "http://cn-orc-1.dataone.org/cn" )

# Debugging messages, disable=0, enable=1 
DEBUG=0

# XML request header
XMLACCEPT="Accept: text/xml"

# Location of curl on your system ( http://curl.haxx.se/ )
CURL="/usr/bin/curl"

#Maximum seconds to consume in a single curl operation
CURLTIMEOUT=5

# Location of XMLStarlet on your system ( http://xmlstar.sourceforge.net/ )
XML=/usr/local/bin/xml

# Location of URLencode script 
# ( http://www.shelldorado.com/scripts/cmds/urlencode )
URLENCODE="`dirname $0`/lib/urlencode"

# Location of XSLT files
XSLTFILES="`dirname $0`/lib"

# 0 = Leave temp files, 1 = remove temp files when done.
REMOVEFILES=1

# Set to non-blank to spit out more information related to errors encountered
VERBOSE=""

#Set the environment variable CNBASE to change the root CN BaseURL
if [ -z $CNBASE ]; then
  CNBASE="http://cn-dev.dataone.org/cn"
fi

#Set the environment variable TEMPFILES to change the location of temporary
# file output
if [ -z $TEMPFILES ]; then
  TEMPFILES="/tmp"
fi

REGISTRY_DOC="d1_registry.xml"
TEMPOUTPUT="d1_test_output"
DEFAULTGETOUTPUT="d1_get_output"

NS_OBJECTLIST="http://dataone.org/service/types/0.5.1"

N_PING="health/ping"
N_NODES="node"
N_OBJECT="object"
N_RESOLVE="resolve"
N_META="meta"

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
  if [ $REMOVEFILES -eq 1 ]; then
    if [ $DEBUG -eq 1 ]; then
      echo "DEBUG: Removing temporary files"
    fi
    rm -f "$TEMPFILES/$REGISTRY_DOC"
    rm -f "$TEMPFILES/$TEMPOUTPUT"
  fi
}

function join_url_paths(){
  TMP_URL=${1%/}/${2#/}
}

function show_known_cns(){
  #Just list the contents of COORDINATING_NODES
  for CN in ${COORDINATING_NODES[@]}; do
    echo $CN
  done
}


function load_registry_doc(){
  #Loads a node registry doc from a coordinating node
  if [ ! -e $REGISTRY_DOC ]; then
    join_url_paths $CNBASE $N_NODES
    `$CURL -m $CURLTIMEOUT -H "$XMLACCEPT" -s \
     -o "$TEMPFILES/$REGISTRY_DOC" $TMP_URL`
  fi
}


function list_nodes(){
  #Set a space delimited list of node identifiers from the registry
  load_registry_doc
  NODELIST=`cat "$TEMPFILES/$REGISTRY_DOC" | $XML tr \
            "$XSLTFILES/registry_select_nodes.xsl"`
}

function node_alive() {
  #Determine if there's a HTTP service running at the URL
  HTTPCODE=`$CURL -m $CURLTIMEOUT -s -w "%{http_code}" \
            -o "$TEMPFILES/$TEMPOUTPUT" $1`
  case "$HTTPCODE" in
    "200")  printf "%s %6s %s\n" "${txtgrn}OK    ${txtrst}" $HTTPCODE $1
            ;;
    "400")  printf "%s %6s %s\n" "${txtgrn}ERROR ${txtrst}" $HTTPCODE $1
            ;;
    "401")  printf "%s %6s %s\n" "${txtgrn}ERROR ${txtrst}" $HTTPCODE $1
            ;;
    "404")  printf "%s %6s %s\n" "${txtgrn}ERROR ${txtrst}" $HTTPCODE $1
            ;;
    "000")  printf "%s %6s %s\n" "${txtred}FAIL  " $HTTPCODE "$1${txtrst}"
            ;;
  esac  
}


function ping_node() {
  join_url_paths $1 $N_PING
  HTTPCODE=`$CURL -m $CURLTIMEOUT -s -w "%{http_code}" \
            -o "$TEMPFILES/$TEMPOUTPUT" $TMP_URL`
  if [ $HTTPCODE = "200" ]; then
    printf "%s %6s %s\n" "${txtgrn}OK  ${txtrst}" $HTTPCODE $1
  else
    printf "%s %6s %s\n" "${txtred}FAIL" $HTTPCODE "$1${txtrst}"
    if [ ! -z $VERBOSE ]; then
      echo "================="
      cat "$TEMPFILES/$TEMPOUTPUT"
      echo "================="
    fi
  fi
}


function ping_node_id(){
  #Check if node with id is alive 
  get_node_baseurl $1
  if [ $2 -eq 0 ]; then
    ping_node $BASEURL
  else
    node_alive $BASEURL
  fi
}


function get_node_baseurl(){
  #Set the BASEURL variable given a node identifier
  load_registry_doc
  BASEURL=`cat "$TEMPFILES/$REGISTRY_DOC" | $XML sel -T -t \
    -m "//node/identifier[text()='$1']" -v "../baseURL"`
}


function get_object_list(){
  join_url_paths $1 $N_OBJECT
  TMP_URL="$TMP_URL?start=$2&count=$3"
  echo $TMP_URL
  $CURL -m $CURLTIMEOUT -s -H "Accept: text/xml" -o "$TEMPFILES/$TEMPOUTPUT" \
        $TMP_URL
  OBJECTLIST=`cat "$TEMPFILES/$TEMPOUTPUT" | $XML sel -N d1=$NS_OBJECTLIST \
    -t -m "//d1:objectList" \
    -o "START=" -v "@start" -o " COUNT=" -v "@count" -o " TOTAL=" -v "@total" \
    -n -m "//identifier" -v "." -o " " -v "../size" -o " " \
    -v "../objectFormat" -n` 
}


function resolve_object_nodes(){
  # sets NODEIDS = an array of node identifiers holding the specified object
  #$1 = identifier of object to resolve
 
  IDENTIFIER="`echo $1 | $URLENCODE`"
  join_url_paths $CNBASE $N_RESOLVE
  join_url_paths $TMP_URL $IDENTIFIER
  $CURL -m $CURLTIMEOUT -s -H "Accept: text/xml" -o "$TEMPFILES/$TEMPOUTPUT" \
        $TMP_URL
  NODEIDS=( `cat $TEMPOUTPUT | $XML sel -T -t \
    -m "//objectLocation/nodeIdentifier" -v . -n` )
  return 0
}


function get_system_metadata(){
  # loads system metadata for object with identifier $1 to
  # "$TEMPFILES/$TEMPOUTPUT"
  IDENTIFIER="`echo $1 | $URLENCODE`"
  join_url_paths $CN_BASE $N_META
  join_url_paths $TMP_URL $IDENTIFIER
  $CURL -m $CURLTIMEOUT -s -H "Accept: text/xml" $TMP_URL | \
  $XML fo -s 2 > "$TEMPFILES"/"$TEMPOUTPUT"
}


function get_object(){
  #retrieves object with id $1 from the preferred node and stores it to $2
  TARGET=$2
  if [ -z ${TARGET} ]; then
    TARGET="$TEMPFILES/$DEFAULTGETOUTPUT"
  fi 
  resolve_object_nodes $1
  get_node_baseurl ${NODEIDS[0]}
  #URL="${BASEURL}object/${IDENTIFIER}"
  join_url_paths ${BASEURL} $N_OBJECT
  join_url_paths $TMP_URL ${IDENTIFIER}
  echo $TMP_URL
  
  $CURL -m $CURLTIMEOUT $TMP_URL > $TARGET
  echo "Output saved to $TARGET"
}


