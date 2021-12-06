#! /usr/bin/env python
#
# Copyright (c) 2008-2011 University of Utah and the Flux Group.
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
import time

ACCEPTSLICENAME=1

execfile( "test-common.py" )

#
# Get a credential for myself, that allows me to do things at the SA.
#
mycredential = get_self_credential()
if debug:
    print "Got my SA credential. Looking for slice ..."

#
# Lookup slice.
#
myslice = resolve_slice( SLICENAME, mycredential )
if debug:
    print "Found the slice, asking for a credential ..."

#
# Get the slice credential.
#
slicecred = get_slice_credential( myslice, mycredential )
if debug:
    print "Got the slice credential, asking for a sliver credential ..."

#
# Get the sliver credential.
#
params = {}
params["credentials"] = (slicecred,)
params["slice_urn"]   = myslice["urn"]
rval,response = do_method("cm", "GetSliver", params, version="2.0")
if rval:
    Fatal("Could not get Sliver credential")
    pass
slivercred = response["value"]
if debug:
    print "Got the sliver credential.  Polling sliver status..."

#
# Poll for the sliver status.  It would be nice to use WaitForStatus
# here, but SliverStatus is more general (since it falls in the minimal
# subset).
#
params = {}
params["slice_urn"]   = myslice["urn"]
params["credentials"] = (slivercred,)
# Python does not have do loops
while True: 
    rval,response = do_method("cm", "SliverStatus", params, version="2.0")
    if rval:
        Fatal("Could not get sliver status")
    if response[ "value" ][ "status" ] == "ready": # no #@(%ing switch, either
        break
    elif response[ "value" ][ "status" ] == "changing":
        time.sleep( 3 )
    else:
        Fatal( "Sliver state is " + response[ "value" ][ "status" ] )

if debug:
    print "Sliver is ready.  Resolving slice at the CM..."

#
# Resolve the slice at the CM, to find the sliver URN.
#
params = {}
params["urn"] = myslice["urn"]
params["credentials"] = (slicecred,)
rval,response = do_method("cm", "Resolve", params, version="2.0")
if rval:
    Fatal("Could not resolve slice")
    pass
sliver_urn = response[ "value" ][ "sliver_urn" ]

if debug:
    print "Got the sliver URN.  Resolving manifest..."

#
# Resolve the sliver at the CM, to find the manifest.
#
params = {}
params["urn"] = sliver_urn
params["credentials"] = (slicecred,)
rval,response = do_method("cm", "Resolve", params, version="2.0")
if rval:
    Fatal("Could not resolve sliver")
    pass

print response[ "value" ][ "manifest" ]
