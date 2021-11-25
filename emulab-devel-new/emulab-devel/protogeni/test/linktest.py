#! /usr/bin/env python
#
# Copyright (c) 2008-2015 University of Utah and the Flux Group.
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

ACCEPTSLICENAME=1
dokill = 0;
action = "start"

execfile( "test-common.py" )

if len(REQARGS) == 1 and REQARGS[0] == "kill":
    dokill = 1
    action = "kill"
pass

#
# Get a credential for myself, that allows me to do things at the SA.
#
mycredential = get_self_credential()
print "Got my SA credential. Looking for slice ..."

#
# Lookup slice.
#
myslice = resolve_slice( SLICENAME, mycredential )
print "Found the slice, asking for a credential ..."

#
# Get the slice credential.
#
slicecred = get_slice_credential( myslice, mycredential )
print "Got the slice credential, " + action + "ing linktest ..."

#
# Start Linktest
#
params = {}
params["slice_urn"]   = myslice["urn"]
params["credentials"] = (slicecred,)
if dokill:
    params["action"] = "stop"
else:
    params["action"] = "start"
    params["level"]  = 1
    params["async"]  = 1
    pass
rval,response = do_method("cm", "RunLinktest", params, version="2.0")
if rval:
    Fatal("Could not " + action + " Linktest")
    pass
print str(response["value"])
