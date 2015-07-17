
# console colors, use echo -e ...
_XCOLOR='\033[0;30m' #black
_RCOLOR='\033[0;31m' #red
_GCOLOR='\033[0;32m' #green
_YCOLOR='\033[0;33m' #yellow
_BCOLOR='\033[0;34m' #blue
_MCOLOR='\033[0;35m' #magenta
_CCOLOR='\033[0;36m' #cyan
_WCOLOR='\033[0;37m' #white

# Bold
_BXCOLOR='\033[1;30m' #black
_BRCOLOR='\033[1;31m' #red
_BGCOLOR='\033[1;32m' #green
_BYCOLOR='\033[1;33m' #yellow
_BBCOLOR='\033[1;34m' #blue
_BMCOLOR='\033[1;35m' #magenta
_BCCOLOR='\033[1;36m' #cyan
_BWCOLOR='\033[1;37m' #white

_INVCOLOR='\033[7m' #inverted

_NCOLOR='\033[0m'     #reset


function showVersion() {
  echo ${VERSION}
}


function locateXML() {
  CANDIDATE=`which xml`
  if [[ -x ${CANDIDATE} ]]; then
      # We're good to go, use CANDIDATE
      XML=${CANDIDATE}
  else
    # MAYBE its called XMLSTARLET 
    CANDIDATE=`which xmlstarlet`
    if [[ -x ${CANDIDATE} ]]; then
      # We're good to go, use CANDIDATE
      XML=${CANDIDATE}
    else
      # Nothing found on path, try the standard location
      CANDIDATE="/usr/local/bin/xml"
      if [[ -x ${CANDIDATE} ]]; then
        XML=${CANDIDATE}
      else
        # Can't find xmlstarlet, so exit
        lerror "Can not locate the 'xml' or 'xmlstarlet' program.  Please install and retry."
        exit
      fi
    fi
  fi
}


function log() {
  if [[ ! -z ${VERBOSE} ]]; then
    local TS=$(date +%Y-%m-%dT%H:%M:%S%z)
    echo -e ${_GCOLOR}"${TS} LOG: $@"${_NCOLOR} 1>&2;
  fi
}


function lwarn() {
  local TS=$(date +%Y-%m-%dT%H:%M:%S%z)
  echo -e ${_RCOLOR}"${TS} WARN: $@"${_NCOLOR} 1>&2;
}


function lerror() {
  local TS=$(date +%Y-%m-%dT%H:%M:%S%z)
  echo -e ${_BRCOLOR}"${TS} ERROR: $@"${_NCOLOR} 1>&2;
}


# Return 1 if first argument occurs in the list of remaining arguments
# http://stackoverflow.com/questions/3685970/check-if-an-array-contains-a-value
# array=("something to search for" "a string" "test2000")
# containsElement "a string" "${array[@]}"
# echo $?
# 0
function containsElement () {
  local e
  for e in "${@:2}"; do [[ "$e" == "$1" ]] && return 0; done
  return 1
}


