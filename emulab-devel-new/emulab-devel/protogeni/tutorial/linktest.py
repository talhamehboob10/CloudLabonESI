#! /usr/bin/env python
#
# Copyright (c) 2008-2010 University of Utah and the Flux Group.
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
import time
import re
import xmlrpclib
from M2Crypto import X509

ACCEPTSLICENAME=1

execfile( "test-common.py" )

#
# Get a credential for myself, that allows me to do things at the SA.
#
mycredential = get_self_credential()
print "Got my SA credential"

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
# Get a ticket. We do not have a real resource discovery tool yet, so
# as a debugging aid, you can wildcard the uuid, and the CM will find
# a free node and fill it in.
#
print "Asking for a ticket from the local CM"

rspec = "<rspec xmlns=\"http://protogeni.net/resources/rspec/0.1\"> " +\
        " <node virtual_id=\"geni1\" "+\
        "       virtualization_type=\"emulab-vnode\" " +\
        "       exclusive=\"1\"> " +\
        "   <interface virtual_id=\"virt0\"/> " +\
        " </node>" +\
        " <node virtual_id=\"geni2\" "+\
        "       virtualization_type=\"emulab-vnode\" " +\
        "       exclusive=\"1\"> " +\
        "   <interface virtual_id=\"virt0\"/> " +\
        " </node>" +\
        " <link virtual_id=\"link0\"> " +\
        "  <interface_ref " +\
        "            virtual_interface_id=\"virt0\" " +\
        "            virtual_node_id=\"geni1\" " +\
        "            /> " +\
        "  <interface_ref " +\
        "            virtual_interface_id=\"virt0\" " +\
        "            virtual_node_id=\"geni2\" " +\
        "            /> " +\
        " </link> " +\
        "</rspec>"
params = {}
params["credential"] = myslice
params["rspec"]      = rspec
rval,response = do_method("cm", "GetTicket", params)
if rval:
    if response and response["value"]:
        print >> sys.stderr, ""
        print >> sys.stderr, str(response["value"])
        print >> sys.stderr, ""
        pass
    Fatal("Could not get ticket")
    pass
ticket = response["value"]
print "Got a ticket from the CM. Redeeming the ticket ..."
if debug: print str(response["output"])

#
# Create the sliver.
#
params = {}
params["credential"] = myslice
params["ticket"]   = ticket
params["keys"]     = mykeys
params["impotent"] = impotent
rval,response = do_method("cm", "RedeemTicket", params)
if rval:
    Fatal("Could not redeem ticket")
    pass
sliver,manifest = response["value"]
print "Created the sliver. Starting the sliver ..."
print str(manifest)

#
# Start the sliver.
#
params = {}
params["credential"] = sliver
params["impotent"]   = impotent
rval,response = do_method("cm", "StartSliver", params)
if rval:
    Fatal("Could not start sliver")
    pass

print "Sliver has been started."
print "You should be able to log into the sliver after a little bit"
print ""
print "Delete this sliver with deletesliver.py"
