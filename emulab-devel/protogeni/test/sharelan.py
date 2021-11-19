#! /usr/bin/env python
#
# Copyright (c) 2008-2013 University of Utah and the Flux Group.
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

ACCEPTSLICENAME=1

def Usage():
    print "usage: " + sys.argv[ 0 ] + " [option...] lanname token "
    print "usage: " + sys.argv[ 0 ] + " [option...] revoke lanname "
    print "Options:"
    BaseOptions()
    pass

debug    = 0
revoke   = 0

execfile( "test-common.py" )

if len(REQARGS) == 2:
    if REQARGS[0] == "revoke":
        lanname = REQARGS[1]
        revoke  = 1
    else:
        lanname = REQARGS[0]
        token   = REQARGS[1]
        pass
else:
    Usage()
    sys.exit(1)
    pass

#
# Get a credential for myself, that allows me to do things at the SA.
#
mycredential = get_self_credential()
print "Got my SA credential"

#
# Lookup slice and get credential.
#
myslice = resolve_slice( SLICENAME, mycredential )

print "Asking for slice credential for " + SLICENAME
slicecredential = get_slice_credential( myslice, mycredential )
print "Got the slice credential"

#
# Create the image
#
params = {}
params["credentials"] = (slicecredential,)
params["slice_urn"]   = myslice["urn"]
params["lanname"]     = lanname
if revoke == 0:
    params["token"]   = token
    print "Sharing the lan ..."
    rval,response = do_method("cm", "ShareLan", params, version="2.0")
    if rval:
        Fatal("Could not share lan")
        pass
    pass
else:
    print "Unsharing the lan ..."
    rval,response = do_method("cm", "UnShareLan", params, version="2.0")
    if rval:
        Fatal("Could not unshare lan")
        pass
    pass


