#! /usr/bin/env python
#
# Copyright (c) 2008-2012 University of Utah and the Flux Group.
# 
# {{{GENIPUBLIC-LICENSE
# 
# GENI Public License
# 
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and/or hardware specification (the "Work") to
# deal in the Work without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Work, and to permit persons to whom the Work
# is furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Work.
# 
# THE WORK IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE WORK OR THE USE OR OTHER DEALINGS
# IN THE WORK.
# 
# }}}
#

#
#
import sys
import pwd
import getopt
import os
import re
import xmlrpclib
import urllib
from xml.sax.handler import ContentHandler
import xml.sax
import xml.dom.minidom
import string

ACCEPTSLICENAME=1

def Usage():
    print "usage: " + sys.argv[ 0 ] + " [option...] rspec-file \
[component-manager-1 component-manager-2]"
    print """Options:
    -c file, --credentials=file         read self-credentials from file
                                            [default: query from SA]
    -d, --debug                         be verbose about XML methods invoked
    -f file, --certificate=file         read SSL certificate from file
                                            [default: ~/.ssl/encrypted.pem]
    -h, --help                          show options and usage
    -n name, --slicename=name           specify human-readable name of slice
                                            [default: mytestslice]
    -p file, --passphrase=file          read passphrase from file
                                            [default: ~/.ssl/password]
    -r file, --read-commands=file       specify additional configuration file
    -s file, --slicecredentials=file    read slice credentials from file
                                            [default: query from SA]

    component-manager-1 and component-manager-2 are hrns
    rspec-file is the rspec to be sent to the two component managers."""

execfile( "test-common.py" )

if len(args) == 1 or len(args) == 3:
    try:
        rspecfile = open(args[ 0 ])
        rspec = rspecfile.read()
        rspecfile.close()
    except IOError, e:
        print >> sys.stderr, args[ 0 ] + ": " + e.strerror
        sys.exit( 1 )
        pass
    if len(args) == 3:
        managers = (args[1], args[2])
    else:
        managers = None;
        pass
else:
    Usage()
    sys.exit( 1 )
    pass

#
# Get a credential for myself, that allows me to do things at the SA.
#
mycredential = get_self_credential()
print "Got my SA credential"

#
# Lookup slice.
#
params = {}
params["credential"] = mycredential
params["type"]       = "Slice"
params["hrn"]        = SLICENAME
rval,response = do_method("sa", "Resolve", params)
if rval:
    #
    # Create a slice. 
    #
    print "Creating new slice called " + SLICENAME
    params = {}
    params["credential"] = mycredential
    params["type"]       = "Slice"
    params["hrn"]        = SLICENAME
    rval,response = do_method("sa", "Register", params)
    if rval:
        Fatal("Could not create new slice")
        pass
    myslice = response["value"]
    print "New slice created"
    pass
else:
    #
    # Get the slice credential.
    #
    print "Asking for slice credential for " + SLICENAME
    myslice = response["value"]
    myslice = get_slice_credential( myslice, mycredential )
    print "Got the slice credential"
    pass


#
# Ask the clearinghouse for a list of component managers. 
#
params = {}
params["credential"] = mycredential
rval,response = do_method("ch", "ListComponents", params)
if rval:
    Fatal("Could not get a list of components from the ClearingHouse")
    pass
components = response["value"];

if managers:
    def FindCM( name, cmlist ):
        for cm in cmlist:
            hrn = cm[ "hrn" ]
            if hrn == name or hrn == name + ".cm":
                return (cm[ "url" ], cm[ "urn" ])
        Fatal( "Could not find component manager " + name )

    url1 = FindCM( managers[ 0 ], components )
    url2 = FindCM( managers[ 1 ], components )
else:
    url1 = "https://www.emulab.net:12369/protogeni/xmlrpc/cm"
    url2 = "https://boss.utah.geniracks.net:12369/protogeni/xmlrpc/cm"
    pass

def DeleteSlivers():
    #
    # Delete the slivers.
    #
    print "Deleting sliver1 now"
    params = {}
    params["credentials"] = (myslice,)
    params["slice_urn"]   = SLICEURN
    rval,response = do_method(None, "DeleteSlice",
                              params, URI=url1, version="2.0")
    if rval:
        Fatal("Could not delete sliver on CM1")
        pass
    print "Sliver1 has been deleted"
    
    print "Deleting sliver2 now"
    params = {}
    params["credentials"] = (myslice,)
    params["slice_urn"]   = SLICEURN
    rval,response = do_method(None, "DeleteSlice",
                              params, URI=url2, version="2.0")
    if rval:
        Fatal("Could not delete sliver on CM2")
        pass
    print "Sliver2 has been deleted"
    sys.exit(0);
    pass

if DELETE:
    DeleteSlivers()
    sys.exit(1)
    pass

#
# Lookup my ssh keys.
#
params = {}
params["credential"] = mycredential
rval,response = do_method("sa", "GetKeys", params)
if rval:
    Fatal("Could not get my keys")
    pass
mykeys = response["value"]
if debug: print str(mykeys)

print "Asking for a ticket from CM1 ..."
params = {}
params["slice_urn"]   = SLICEURN
params["credentials"] = (myslice,)
params["rspec"]       = rspec
rval,response = do_method(None, "GetTicket", params, URI=url1, version="2.0")
if rval:
    if response and response["value"]:
        print >> sys.stderr, ""
        print >> sys.stderr, str(response["value"])
        print >> sys.stderr, ""
        pass
    Fatal("Could not get ticket")
    pass
ticket1 = response["value"]
print "Got a ticket from CM1, asking for a ticket from CM2 ..."

#
# Get a ticket for a node on another CM.
#
params = {}
params["slice_urn"]   = SLICEURN
params["credentials"] = (myslice,)
params["rspec"]       = rspec
rval,response = do_method(None, "GetTicket", params, URI=url2, version="2.0")
if rval:
    if response and response["value"]:
        print >> sys.stderr, ""
        print >> sys.stderr, str(response["value"])
        print >> sys.stderr, ""
        pass
    Fatal("Could not get ticket")
    pass
ticket2 = response["value"]
print "Got a ticket from CM2, redeeming ticket on CM1 ..."

#
# Create the slivers.
#
params = {}
params["credentials"] = (myslice,)
params["ticket"]      = ticket1
params["slice_urn"]   = SLICEURN
params["keys"]        = mykeys
rval,response = do_method(None, "RedeemTicket", params,
                          URI=url1, version="2.0")
if rval:
    Fatal("Could not redeem ticket on CM1")
    pass
sliver1,manifest1 = response["value"]
print "Created a sliver on CM1, redeeming ticket on CM2 ..."
print str(manifest1);

params = {}
params["credentials"] = (myslice,)
params["ticket"]      = ticket2
params["slice_urn"]   = SLICEURN
params["keys"]        = mykeys
rval,response = do_method(None, "RedeemTicket", params,
                          URI=url2, version="2.0")
if rval:
    Fatal("Could not redeem ticket on CM2")
    pass
sliver2,manifest2 = response["value"]
print "Created a sliver on CM2"
print str(manifest2)

#
# Start the slivers.
#
params = {}
params["credentials"] = (sliver1,)
params["slice_urn"]   = SLICEURN
rval,response = do_method(None, "StartSliver", params, URI=url1, version="2.0")
if rval:
    Fatal("Could not start sliver on CM1")
    pass
print "Started sliver on CM1. Starting sliver on CM2 ..."

params = {}
params["credentials"] = (sliver2,)
params["slice_urn"]   = SLICEURN
rval,response = do_method(None, "StartSliver", params, URI=url2, version="2.0")
if rval:
    Fatal("Could not start sliver on CM2")
    pass

print "Slivers have been started"
print "You should be able to log into the sliver after a little bit."
print "Polling CM1 for a while, type ^C to stop."

params = {}
params["slice_urn"]   = SLICEURN
params["credentials"] = (sliver1,)
# Python does not have do loops
while True: 
    rval,response = do_method("cm", "SliverStatus", params,
                              URI=url1, version="2.0")
    if rval:
        if rval != 14:
            Fatal("Could not get sliver status")
            pass
    elif response[ "value" ][ "status" ] == "ready": # no #@(%ing switch, either
        break
    elif response[ "value" ][ "status" ] == "changing":
        print "Not ready, waiting a bit before asking again";
        time.sleep( 5 )
    else:
        Fatal( "Sliver state is " + response[ "value" ][ "status" ] )
        pass
    pass
print "Sliver on CM1 is ready. Polling CM2 now ..."

params = {}
params["slice_urn"]   = SLICEURN
params["credentials"] = (sliver2,)
# Python does not have do loops
while True: 
    rval,response = do_method("cm", "SliverStatus", params,
                              URI=url2, version="2.0")
    if rval:
        if rval != 14:
            Fatal("Could not get sliver status")
            pass
    elif response[ "value" ][ "status" ] == "ready": # no #@(%ing switch, either
        break
    elif response[ "value" ][ "status" ] == "changing":
        print "Not ready, waiting a bit before asking again";
        time.sleep( 5 )
    else:
        Fatal( "Sliver state is " + response[ "value" ][ "status" ] )
        pass
    pass
print "Sliver on CM2 is ready."
