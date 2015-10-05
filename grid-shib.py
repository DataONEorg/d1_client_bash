#!/usr/bin/env python
######################################################################
#
# This file is part of the GriShib-CA distribution.  Copyright
# 2006-2010 The Board of Trustees of the University of
# Illinois. Please see LICENSE at the root of the distribution.
#
######################################################################
"""GridShib-CA Credential Retriever Client

Python client for GridShib-CA.

Requires pyOpenSSL from https://launchpad.net/pyopenssl

Credit to Tom Uram <turam at mcs.anl.gov> for Python MyProxy client.

Todo:
 * Error checking

GridShib-CA Version: 2.0.1

+++
- Retrieved from https://cilogon.org/gridshib-ca/gridshibca-client.py
Modified by DV:
- Added logging to send messages to stderr
- Formatting
- Default trusted certs download to ~/.dataone/certificates
- Default serverURL = https://polo2.cilogon.org//gridshib-ca//GridShibCA.cgi
- stdout single line with location of client certificate
"""

import getpass
from optparse import OptionParser
import os
import sys
from datetime import datetime, timedelta
import urllib
import urllib2
import urlparse
import logging

# Default Server URL (can be overridden with -s on commandline)
#serverURL = "https://cilogon.org//gridshib-ca//GridShibCA.cgi";
serverURL = "https://polo2.cilogon.org//gridshib-ca//GridShibCA.cgi"

# Package version
version="2.0.1"

######################################################################
#
# make sure OpenSSL is installed.

try:
  from OpenSSL import crypto
except ImportError, ex:
  print "Import of OpenSSL module failed: %s" % ex
  print "OpenSSL module is required for this application. You can get it from:"
  print "https://launchpad.net/pyopenssl"
  sys.exit(1)


######################################################################
class GSI:
  """Grid Security Infrastucture utility functions."""

  @staticmethod
  def defaultProxyPath():
    """Return the default location Globus will look for a credential."""
    # I tried using tempfile.gettempdir() here, but it always returns
    # 'temporary' directories as opposed to, e.g., .tmp:
    # e.g. /var/folders/t6/t6puj+oYFsmrOCU8+6+IHU+++TM/-Tmp-
    if sys.platform == 'win32':
      tempdir = "C:\temp" # XXX This is my best guess
    else:
      tempdir = "/tmp"
    filename = "x509up_u%d" % os.getuid()
    return os.path.join(tempdir, filename)

  @staticmethod
  def userCertificatesPath():
    """Return path to users certificates directory."""
    #return os.path.expanduser(os.path.join("~", ".globus", ".certificates"))
    return os.path.expanduser(os.path.join("~", ".dataone", "certificates"))


######################################################################
class GridShibCAException(Exception):
  """Exception for GridShibCA-specific errors."""
  pass


######################################################################
class GridShibCAURL:

  def __init__(self, url):
    global version
    parsedURL = urlparse.urlparse(url)
    if parsedURL.scheme != 'https':
      raise GridShibCAException("Invalid server URL scheme: " + parsedURL.scheme)
    self.url = url
    self.userAgent = "GridShibCA-Python/%s" % version


  def post(self, values):
    """Post a request given the name/values in values dictionary."""
    postData = urllib.urlencode(values)
    logging.debug("Postdata: %s", postData)
    headers = { 'User-Agent' : self.userAgent }
    request = urllib2.Request(self.url, postData, headers)
    connection = urllib2.urlopen(request)
    response = connection.read()
    return response


######################################################################
class GridShibCATrustRootsURL(GridShibCAURL):
  """Download trust roots and store in ~/.globus/certificates."""

  def retrieveTrustRoots(self):
    """Download trust roots and store in ~/.globus/certificates."""
    logging.debug("Requesting trust roots")
    postFields  = {
        "command" : "TrustRoots",
        }
    trustRoots = self.post(postFields).splitlines()
    certsPath = GSI.userCertificatesPath()
    logging.debug("Writing trust roots to %s", certsPath)
    if not os.path.isdir(certsPath):
      os.makedirs(certsPath, 0700)
    file = None
    while len(trustRoots):
      line = trustRoots.pop(0)
      if line.startswith("-----File:"):
        filename = os.path.basename(line[10:])
        logging.debug("New file: %s", filename)
        path = os.path.join(certsPath, filename)
        if file:
          file.close()
        file = open(path, "w")
      else:
        if file:
          file.write(line)
        # If file not open yes, silently ignore line
    if file:
      file.close()
            

######################################################################
class GridShibCACredentialIssuerURL(GridShibCAURL):
  def requestCertificate(self, actCode, lifetime):
    """Request certificate from GridShib-CA. Returns X509Credential object."""
    credential = X509Credential()
    requestPEM = credential.generateRequest()
    logging.debug("Request generated:\n%s", requestPEM)
    postFields = {
        "command" : "IssueCert",
        "lifetime" : lifetime,
        "GRIDSHIBCA_SESSION_ID" : actCode,
        "certificateRequest" : requestPEM,
        }
    logging.debug("Posting request")
    try:
      certificatePEM = self.post(postFields)
    except urllib2.HTTPError, err:
      if err.code == 401:
        raise GridShibCAException("Authentication failed.")
      else:
        raise err
    logging.debug("Got response:\n%s", certificatePEM)
    try:
      certificateX509 = crypto.load_certificate(
          crypto.FILETYPE_PEM, certificatePEM)
    except:
      raise GridShibCAException("Error processing cerificate from server")
    credential.setCertificate(certificateX509)
    return credential


######################################################################
class X509Credential:

  def __init__(self):
    self.privateKey = None
    self.certificate = None

  def generateRequest(self,
                      keyType = crypto.TYPE_RSA,
                      bits = 2048,
                      messageDigest = "sha1"):
    """Generate a request and return the PEM-encoded PKCS10 object."""
    logging.info("Generating private keys and certificate request.")
    self.request = crypto.X509Req()
    self.privateKey = crypto.PKey()
    self.privateKey.generate_key(keyType, bits)
    self.request.set_pubkey(self.privateKey)
    self.request.sign(self.privateKey, messageDigest)
    return crypto.dump_certificate_request(crypto.FILETYPE_PEM,
                                           self.request)
  
  def setCertificate(self, certificate):
    """Use given OpenSSL.crypto.X509 as certificate."""
    self.certificate = certificate

  def writeGlobusCredential(self, path):
    if self.privateKey is None:
      raise GridShibCAException("Attempt to write incomplete credential (private key is missing)")
    if self.certificate is None:
      raise GridShibCAException("Attempt to write incomplete credential (public key is mising)")
    exp_time = datetime.strptime(self.certificate.get_notAfter(),
                                 "%Y%m%d%H%M%SZ") 
    timeleft = exp_time - datetime.utcnow()
    secondsleft = timeleft.seconds + timeleft.days * 24 * 3600
    logging.debug("Certificate lifetime: %d seconds", secondsleft)
    certificatePEM = crypto.dump_certificate(crypto.FILETYPE_PEM,
                                             self.certificate)
    logging.debug("maxcleartextlifetime: %d seconds", maxcleartextlifetime)
    if secondsleft > maxcleartextlifetime:
      logging.debug("Writing encrypted private key")
      passphrase = verify = ""
      while len(passphrase) < minpasslen:
        passphrase = getpass.getpass("Please enter a %d character (or longer) passphrase to protect your private key: " % minpasslen).strip();
        verify = getpass.getpass("Verify passphrase: ").strip();
        if len(passphrase) < minpasslen:
          print "Passphrase too short, please try again..."
          passphrase = verify = ""
        elif passphrase != verify:
          print "Passphrase mismatch, please try again..."
          passphrase = verify = ""

      privateKeyPEM = crypto.dump_privatekey(crypto.FILETYPE_PEM,
                                            self.privateKey,
                                            "des-ede-cbc",
                                            passphrase)
    else:
      privateKeyPEM = crypto.dump_privatekey(crypto.FILETYPE_PEM,
                                             self.privateKey)
    if os.path.exists(path):
      os.remove(path)
    # O_EXCL|O_CREAT to prevent a race condition where someone
    # else opens the file first.
    fd = os.open(path, os.O_WRONLY|os.O_CREAT|os.O_EXCL, 0600)
    file = os.fdopen(fd, "w")
    file.write(certificatePEM)
    file.write(privateKeyPEM)
    file.close()


######################################################################
def main(argv=None):
  # Do argv default this way, as doing it in the functional
  # declaration sets it at compile time.
  if argv is None:
    argv = sys.argv

  global maxcleartextlifetime
  global minpasslen

  parser = OptionParser(
      usage="%prog [<options>] <some arg>", # printed with -h/--help
      version="%prog 2.0.1" # printer with --verion
      )
  parser.add_option("-a", "--actCode",
                    dest="actCode", default=None,
                    help="specify Activation Code", metavar="ACTCODE")
  parser.add_option("-c", "--maxcleartextlifetime",
                    dest="maxcleartextlifetime", default=1000000,
                    help="maximum seconds before passphrase is required")
  parser.add_option("-d", "--debug",
                    dest="debug", action="store_true", default=False,
                    help="show debug messages")
  parser.add_option("-l", "--lifetime",
                    dest="lifetime", default=43200,
                    help="requested certificate lifetime (seconds)")
  parser.add_option("-p", "--minpasslen",
                    dest="minpasslen", default=12,
                    help="minimum passphrase length (# of characters)")
  parser.add_option("-q", "--quiet",
                    dest="quiet", action="store_true", default=False,
                    help="run quietly")
  parser.add_option("-s", "--server", dest="serverURL", default=serverURL,
                    help="use URL for server address", metavar="URL")
  parser.add_option("-T", "--trustroots",
                    dest="getTrustRoots", action="store_true", default=False,
                    help="download trust roots")
  parser.add_option('-v', '--verbose', dest='llevel', default=20, type='int',
              help='Reporting level: 10=debug, 20=Info, 30=Warning, ' +\
                   '40=Error, 50=Fatal [default: %default]')
  (options, args) = parser.parse_args()
  if options.llevel not in [10,20,30,40,50]:
    options.llevel = 20
  logging.basicConfig(level=int(options.llevel))    
  displayProgress = not options.quiet
  displayDebug = options.debug
  maxcleartextlifetime = int(options.maxcleartextlifetime)
  minpasslen = int(options.minpasslen)
  logging.debug("GridShib CA client starting up")
  try:
    logging.debug("Server URL is %s", options.serverURL)
    credIssuer = GridShibCACredentialIssuerURL(options.serverURL)
  except Exception, ex:
    print "Error parsing server URL: %s" % ex
    sys.exit(1)
  if options.actCode:
    actCode = options.actCode
  else:
    # Strip string since put'n'paste seems to add occassional whitespace
    actCode = getpass.getpass("Please enter your Activation Code: ").strip();
  logging.info("Using GridShib CA server at %s", options.serverURL)
  try:
    credential = credIssuer.requestCertificate(actCode, options.lifetime)
  except Exception, err:
    logging.exception(err)
    sys.exit(1)
  path = GSI.defaultProxyPath()
  logging.debug("Got credential. Writing.")
  credential.writeGlobusCredential(path)
  logging.info("Credential written to %s", path)
  if options.getTrustRoots:
    try:
      logging.info("Retrieving trust roots.")
      url = GridShibCATrustRootsURL(options.serverURL)
      url.retrieveTrustRoots()
    except urllib2.HTTPError, err:
      logging.exception("Error retrieving trust roots:\n", err)
      sys.exit(1)
  logging.info("Success.")
  print path
  sys.exit(0)


######################################################################
if __name__ == "__main__":
  main()
