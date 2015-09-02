# A few common variables and operations for reuse.

# This work was created by participants in the DataONE project, and is
# jointly copyrighted by participating institutions in DataONE. For
# more information on DataONE, see our web site at https://dataone.org.
#
#   Copyright 2015
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#xmlstarlet application
XML="xml"

#Location of configuration info required for some scripts.
DATAONE_CONFIG_FOLDER="${HOME}/.dataone"
DATAONE_CONFIG="${DATAONE_CONFIG_FOLDER}/d1bash.cfg"

#Default client certificate
MY_CLIENT_CERT=""
if [[ -f "${DATAONE_CONFIG_FOLDER}/private/client_cert.pem" ]]; then
  MY_CLIENT_CERT="${DATAONE_CONFIG_FOLDER}/private/client_cert.pem"
fi

#Default Coordinating NODE base URL to use
if [[ -z ${NODE} ]]; then
  NODE="https://cn.dataone.org/cn"
fi

#Default Member NODE base URL
if [[ -z ${MNODE} ]]; then
  MNODE=""
fi

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

_INVCOLOR='\033[7m'   #inverted

_NCOLOR='\033[0m'     #reset

# Set the logging level
# >0 = error
# >1 = + warn
# >2 = + info
# >3 = + debug
LOGLEVEL=3

## Variables defined before here can be overridden by the
## values in $DATAONE_CONFIG

# Load user settings if present
if [[ -f ${DATAONE_CONFIG} ]]; then
  source ${DATAONE_CONFIG}
fi

showVersion() {
  echo ${VERSION}
}


# Find the xmlstarlet app or bail
locateXML() {
  local CANDIDATE=`which xml`
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
        exit 2
      fi
    fi
  fi
}

# Write a debug message to stderr. All call parameters are output.
ldebug() {
  if [ ${LOGLEVEL} -gt 3 ]; then
    local TS=$(date +%Y-%m-%dT%H:%M:%S%z)
    echo -e ${_CCOLOR}"${TS} DEBUG: $@"${_NCOLOR} 1>&2;
  fi
}


linfo() {
  if [ ${LOGLEVEL} -gt 2 ]; then
    local TS=$(date +%Y-%m-%dT%H:%M:%S%z)
    echo -e ${_GCOLOR}"${TS} INFO: $@"${_NCOLOR} 1>&2;
  fi 
}


# Write a warning message to stderr. All call parameters are output.
lwarn() {
  if [ ${LOGLEVEL} -gt 1 ]; then
    local TS=$(date +%Y-%m-%dT%H:%M:%S%z)
    echo -e ${_RCOLOR}"${TS} WARN: $@"${_NCOLOR} 1>&2;
  fi
}


# Write an error message to stderr. All call parameters are output.
lerror() {
  if [ ${LOGLEVEL} -gt 0 ]; then
    local TS=$(date +%Y-%m-%dT%H:%M:%S%z)
    echo -e ${_BRCOLOR}"${TS} ERROR: $@"${_NCOLOR} 1>&2;
  fi
}


# Return 0 if first argument occurs in the list of remaining arguments
# http://stackoverflow.com/questions/3685970/check-if-an-array-contains-a-value
# array=("something to search for" "a string" "test2000")
# containsElement "a string" "${array[@]}"
# echo $?
# 0
containsElement () {
  local e
  for e in "${@:2}"; do [[ "$e" == "$1" ]] && return 0; done
  return 1
}


# Escapes $1 as a term for a solr query
escapeSolrTerm() {
  local _t="${2//\\/\\\\}"
  _t="${_t//:/\\:}"
  _t="${_t//+/\\+}"
  _t="${_t//-/\\-}"
  _t="${_t//[/\\[}"
  _t="${_t//]/\\]}"
  _t="${_t//(/\\(}"
  _t="${_t//)/\\)}"
  #_t="${_t//\//\\\/}"
  echo "${_t}"
}


# $1 = URL
# $2 = Key
# $3 = Value (will be URL encoded)
# updates ${URL}
addURLKV()
{
  delim="?"
  if [[ "${1}" == *\?* ]]; then
    delim="&"
  fi
  uval=$(echo $3 | ${URLENCODE})
  URL="${1}${delim}${2}=${uval}"
}

