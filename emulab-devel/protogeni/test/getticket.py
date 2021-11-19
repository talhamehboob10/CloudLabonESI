#! /usr/bin/env python
#
# Copyright (c) 2008-2014 University of Utah and the Flux Group.
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

ACCEPTSLICENAME=1

execfile( "test-common.py" )

if len(REQARGS) > 1:
    Usage()
    sys.exit( 1 )
elif len(REQARGS) == 1:
    try:
        rspecfile = open(REQARGS[0])
        rspec = rspecfile.read()
        rspecfile.close()
    except IOError, e:
        print >> sys.stderr, args[ 0 ] + ": " + e.strerror
        sys.exit( 1 )
else:
    rspec = "<rspec xmlns=\"http://protogeni.net/resources/rspec/0.1\"> " +\
            " <node virtual_id=\"geni1\" "+\
            "       virtualization_type=\"emulab-vnode\"> " +\
            " </node>" +\
            "</rspec>"
    pass

#
# Get a credential for myself, that allows me to do things at the SA.
#
mycredential = get_self_credential()
print "Got my SA credential, looking up " + SLICENAME

#
# Lookup slice and get credential.
#
myslice = resolve_slice( SLICENAME, mycredential )

print "Asking for slice credential for " + SLICENAME
slicecredential = get_slice_credential( myslice, mycredential )
print "Got the slice credential"

#
# Get a ticket. We do not have a real resource discovery tool yet, so
# as a debugging aid, you can wildcard the uuid, and the CM will find
# a free node and fill it in.
#
print "Asking for a ticket from the local CM"

params = {}
params["slice_urn"]   = myslice["urn"]
params["credentials"] = (slicecredential,)
params["rspec"]       = rspec
params["impotent"]    = 0
rval,response = do_method("cm", "GetTicket", params, version="2.0")
if rval:
    Fatal(response["value"])
    pass
ticket = response["value"]
print str(ticket)
sys.exit(0)

#
# Update the ticket. Send back the original rspec, but technically wrong.
# Proper to dig out the rspec from the ticket and use that, modified if
# desired. 
#
#print "Got the ticket, doing a update on it. "
#params = {}
#params["slice_urn"]   = myslice["urn"]
#params["ticket"]      = ticket
#params["credentials"] = (slicecredential,)
#params["rspec"]       = rspec
#params["impotent"]    = 0
#rval,response = do_method("cm", "UpdateTicket", params, version="2.0")
#if rval:
#    Fatal("Could not update ticket")
#    pass
#ticket = response["value"]
#print "Updated the ticket."
#print str(ticket)
