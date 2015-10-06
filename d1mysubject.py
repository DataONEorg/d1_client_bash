#!/usr/bin/env python

'''Given a certificate, show the subject in DataONE format and optionally 
display included subject information such as mapped identities and group 
memberships.
'''

import sys
import os
import logging
import argparse
from OpenSSL import crypto
from pyasn1.error import PyAsn1Error
from pyasn1.codec.ber import decoder
from lxml import etree

VERSION="2.0.0"

NAMESPACES = {
  "d1" : "http://ns.dataone.org/service/types/v1",
  "d1_1": "http://ns.dataone.org/service/types/v1.1",
  "d1_2": "http://ns.dataone.org/service/types/v2.0",
  }


def showVersion():
  print "%s version %s" % (os.path.basename(__file__), VERSION)


def getSubjectFromName(xName):
  '''Given a DN, returns a DataONE subject
  TODO: This assumes that RDNs are in reverse order...
  
  @param 
  '''
  parts = xName.get_components()
  res = []
  for part in parts:
    res.append("%s=%s" % (part[0].upper(), part[1]))
  res.reverse()
  return ",".join(res)


def dumpExtensions(x509):
  decoder.decode.defaultErrorState = decoder.stDumpRawValue
  nExt = x509.get_extension_count()
  logging.debug("There are %d extensions in this certificate" % nExt)
  for i in xrange(0, nExt):
    ext = x509.get_extension(i)
    logging.debug("Extension %d:" % i)
    logging.debug("  Name: %s" % ext.get_short_name())
    try:
      v = decoder.decode(ext.get_data())
      logging.debug("  Value: %s" % str(v))
    except PyAsn1Error, err:
      logging.warn(err)
      logging.debug("  Value: %s" % str(ext.get_data()))
  

def getMatchingSubjectInfoFromCert(x509):
  '''Retrieve a list of strings from the x509 extensions that contain 
  the string "subjectInfo".
  '''
  # This is a huge hack, though it works nicely - iterate through the extensions 
  # looking for a UTF8 object that contains the string "subjectInfo". The 
  # extension has no name, and the OpenSSL lib currently has no way to retrieve 
  # the extension by OID which is 1.3.6.1.4.1.34998.2.1 for the DataONE 
  # subjectInfo extension.
  #
  # A caller should check that the returned data is a valid subjectInfo 
  # structure
  decoder.decode.defaultErrorState = decoder.stDumpRawValue
  nExt = x509.get_extension_count()
  res = []
  for i in xrange(0, nExt):
    ext = x509.get_extension(i)
    sv = decoder.decode(ext.get_data())
    if str(sv).find("subjectInfo") >= 0:
      res.append( sv[0] )
  return res


def getSubjectInfoFromCert(x509):
  matches = getMatchingSubjectInfoFromCert(x509)
  for match in matches:
    try:
      match = str(match)
      #Verify the thing is valid XML
      logging.debug("Loading xml structure")
      doc = etree.fromstring( match )
      #Is this a subject info structure?
      logging.debug("Looking for subjectInfo element...")
      for ns in NAMESPACES:
        test = "{%s}subjectInfo" % NAMESPACES[ns]
        if doc.tag == test:
          logging.debug("Match on %s" % test)
          return match
    except Exception, e:
      logging.exception( e )
      pass
  return None


def getSubjectFromCertFile(certFileName):
  status = 1
  certf = file(certFileName, "rb")
  x509 = crypto.load_certificate(crypto.FILETYPE_PEM, certf.read())
  certf.close()
  dumpExtensions(x509)
  if x509.has_expired():
    logging.warn("Certificate has expired!")
    status = 0
  else:
    logging.info("Certificate OK")
    status = 1
  logging.info("Issuer: %s" % getSubjectFromName(x509.get_issuer()))
  logging.info("Not before: %s" % x509.get_notBefore())
  logging.info("Not after: %s"  % x509.get_notAfter())
  return {'subject': getSubjectFromName(x509.get_subject()),
          'subjectInfo': getSubjectInfoFromCert(x509),
          }, status


if __name__ == "__main__":
  parser = argparse.ArgumentParser(
    description="Show client certificate information" )
  parser.add_argument('--loglevel', '-l', type=int, nargs=1, default=20,
    help='Reporting level: 10=debug, 20=Info, 30=Warning, ' +\
         '40=Error, 50=Fatal')
  parser.add_argument('--info', '-i', action='store_true',
    help='Output only subjectInfo structure in certificate')
  parser.add_argument('--format', '-f', action='store_true',
    help='Format subject add info output for people')
  parser.add_argument('--version', '-v', action='store_true',
    help="Show version and exit.")
  parser.add_argument('certfile',
    help='Certificate file name.')

  options = parser.parse_args()
  llevel = options.loglevel[0]
  if llevel not in [10,20,30,40,50]:
    llevel = 20
  logging.basicConfig(level=llevel)
  if options.version:
    showVersion();
    sys.exit(0)
  
  fname = options.certfile
  subject, status = getSubjectFromCertFile(fname)
  logging.debug("Subject = %s", repr(subject))
  if options.info:
    #Request to output just subjectInfo to stdout
    if subject['subjectInfo'] is not None:
      if options.format:
        root = etree.fromstring( subject['subjectInfo'] )
        print etree.tostring( root, pretty_print=True, encoding='UTF-8', 
                              xml_declaration=True )
      else:
        print subject['subjectInfo']
  else:
    #Otherwise output everything
    print subject['subject']
    if subject['subjectInfo'] is not None:
      if options.format:
        root = etree.fromstring( subject['subjectInfo'] )
        print "SubjectInfo:"
        print etree.tostring( root, pretty_print=True, encoding='UTF-8', 
                              xml_declaration=True )
      else:
        print subject['subjectInfo']
  if status == 0:
    sys.exit(2)
  sys.exit(0)
