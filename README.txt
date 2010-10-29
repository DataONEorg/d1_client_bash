README for d1_client_bash
=========================

These bash scripts offer command line convenience for basic interaction with
DataONE CNs and MNs without the need for Java or Python libraries.

Note:

* There's pretty much no error checking 

* There is minimal dependence on schema structures since the content is extract 
  with (mostly) namespace independent xpath


Installation
------------

1. Install curl_

2. Install XMLstarlet_

3. ``cd`` to this folder and do stuff


.. _curl: http://curl.haxx.se/

.. _XMLstarlet: http://xmlstar.sourceforge.net/ 


Examples
--------

Example: List all nodes::

  $ ./d1_listnodes
  ID  Name  BaseURL
  cn-dev  cn_dev  http://cn-dev.dataone.org/cn/ 
  http://mn-dev.dataone.org DataONESamples  http://mn-dev.dataone.org/mn/ 
  http://dev-dryad-mn.dataone.org dryad http://dev-dryad-mn.dataone.org/mn/ 
  http://daacmn.dataone.utk.edu ornldaac  http://daacmn.dataone.utk.edu/mn/ 
  http://knb-mn.ecoinformatics.org  knb http://knb-mn.ecoinformatics.org/knb/ 
  http://cn-unm-1.dataone.org cn-unm-1  http://cn-unm-1.dataone.org/cn/ 
  http://cn-ucsb-1.dataone.org  cn-ucsb-1 http://cn-ucsb-1.dataone.org/cn/ 
  http://cn-orc-1.dataone.org cn-orc-1  http://cn-orc-1.dataone.org/cn/ 


Example: Low level (HTTP) ping of nodes::

  $ ./d1_ping
  OK  CODE=200  ID=cn-dev   URL=http://cn-dev.dataone.org/cn/ 
  FAIL  CODE=000  ID=http://mn-dev.dataone.org  URL=http://mn-dev.dataone.org/mn/ 
  FAIL  CODE=404  ID=http://dev-dryad-mn.dataone.org  URL=http://dev-dryad-mn.dataone.org/mn/ 
  FAIL  CODE=404  ID=http://daacmn.dataone.utk.edu  URL=http://daacmn.dataone.utk.edu/mn/ 
  FAIL  CODE=503  ID=http://knb-mn.ecoinformatics.org   URL=http://knb-mn.ecoinformatics.org/knb/ 
  OK  CODE=200  ID=http://cn-unm-1.dataone.org  URL=http://cn-unm-1.dataone.org/cn/ 
  OK  CODE=200  ID=http://cn-ucsb-1.dataone.org   URL=http://cn-ucsb-1.dataone.org/cn/ 
  OK  CODE=200  ID=http://cn-orc-1.dataone.org  URL=http://cn-orc-1.dataone.org/cn/ 


Example: List objects::

  $ ./d1_listobjects 
  START=0 COUNT=16 TOTAL=16
  test201030214278702 12 text/csv
  knb:testid:2010302142651722 12 eml://ecoinformatics.org/eml-2.1.0
  knb:testid:2010302123624795 12 text/csv
  knb:testid:2010302142527155 12 text/csv
  knb:testid:2010302142228258 12 text/csv
  knb:testid:2010302125029284 12 text/csv
  knb:testid:2010302142227709 12 text/csv
  test2010302125226397 12 text/csv
  knb:testid:2010302142527649 12 text/csv
  knb:testid:2010302125028653 12 text/csv
  test20103021236250 12 text/csv
  knb:testid:2010302123624165 12 text/csv
  knb:testid:201030212381820 12 eml://ecoinformatics.org/eml-2.1.0
  knb:testid:2010302142353879 12 eml://ecoinformatics.org/eml-2.1.0
  knb:testid:201030212525850 12 eml://ecoinformatics.org/eml-2.1.0
  test2010302142413245 12 text/csv


Example: Resolve object identifier to holding nodes::

  $ ./d1_resolve knb:testid:2010302142227709
  cn-dev


Example: Get system metadata for an object:

  $ ./d1_getsysm knb:testid:2010302142227709
  <?xml version="1.0" encoding="UTF-8"?>
  <d1:systemMetadata xmlns:d1="http://dataone.org/service/types/SystemMetadata/0.5">
    <identifier>knb:testid:2010302142227709</identifier>
    <objectFormat>text/csv</objectFormat>
    <size>12</size>
    <submitter>uid=jones,o=NCEAS,dc=ecoinformatics,dc=org</submitter>
    <rightsHolder>uid=jones,o=NCEAS,dc=ecoinformatics,dc=org</rightsHolder>
    <checksum algorithm="SHA-256">4d6537f48d2967725bfcc7a9f0d5094ce4088e0975fcd3f1a361f15f46e49f83</checksum>
    <dateUploaded>2010-10-29T21:22:27.71Z</dateUploaded>
    <dateSysMetadataModified>2010-10-29T21:22:27.921Z</dateSysMetadataModified>
    <originMemberNode>mn1</originMemberNode>
    <authoritativeMemberNode>mn1</authoritativeMemberNode>
    <replica>
      <replicaMemberNode>cn-dev</replicaMemberNode>
      <replicationStatus>completed</replicationStatus>
      <replicaVerified>2010-10-29T21:22:27.71Z</replicaVerified>
    </replica>
  </d1:systemMetadata>


Example: Download an object to local disk::

  $ ./d1_get knb:testid:2010302142227709 /tmp/temp_object
  http://cn-dev.dataone.org/cn/object/knb%3Atestid%3A2010302142227709
    % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                   Dload  Upload   Total   Spent    Left  Speed
  100 45924    0 45924    0     0  63719      0 --:--:-- --:--:-- --:--:-- 75532
  Output saved to /tmp/temp_object

  $ head -20 /tmp/temp_object
  ## file name :ht90e66:                archival media:
  ##
  ##
  ## The use of any parts of these data requires
  ## written permission from:  David Tilman (Head PI)
  ##
  ## C/O LTER Data Manager
  ## Ecology, Evolution and Behavior
  ## University of Minnesota, 318 Church St. S.E., MPLS, MN 55455
  ##
  ## Header format[Column(i) : variable abbreviation : variable description :format]
  ##
  ##
  ## Column01 : field    : Field number/letter                                     :int[%2d]
  ## Column02 : expt     : Experiment number                                       :int[%2d]
  ## Column03 : plot     : Plot number                                             :int[%3d]
  ## Column04 : trt      : Treatment                                               :int[%1d]
  ## Column05 : taxon    : Species Taxon code                                      :int[%3d]
  ## Column06 : date     : Sampling date                                           :int[%6d]
  ## Column07 : seedsrc  : Seed source                                             :char[%9s]

     