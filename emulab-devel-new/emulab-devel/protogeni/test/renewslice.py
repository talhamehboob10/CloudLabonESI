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
# Renew the slice at the SA *and* the sliver at the CM.
# Also see renewsliver.py ... to just renew the sliver. 
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

minutes = 60
extracred = None;

execfile( "test-common.py" )

if len(REQARGS) < 1:
    print >> sys.stderr, "Must provide number of minutes to renew for"
    sys.exit(1)
    pass

# Always first argument.
minutes = REQARGS[0]
if len(REQARGS) == 2:
    f = open(REQARGS[1])
    extracred = f.read()
    f.close()
    pass

#
# Get a credential for myself, that allows me to do things at the SA.
#
mycredential = get_self_credential()
print "Got my SA credential"

#
# Lookup slice
#
myslice = resolve_slice( SLICENAME, mycredential )
print "Found the slice, asking for a credential ..."

#
# Get the slice credential.
#
slicecred = get_slice_credential( myslice, mycredential )
print "Got the slice credential, renewing the slice at the SA ..."

#
# Bump the expiration time.
#
valid_until = time.strftime("%Y%m%dT%H:%M:%S",
                            time.gmtime(time.time() + (60 * int(minutes))))

#
# Renew the slice at the SA.
#
params = {}
params["credential"] = slicecred
params["expiration"] = valid_until
rval,response = do_method("sa", "RenewSlice", params)
if rval:
    Fatal("Could not renew slice at the SA")
    pass
print "The slice has been renewed successfully."
print "Now asking for slice credential again...";

#
# Get the slice credential again so we have the new time in it.
#
slicecred = get_slice_credential( myslice, mycredential )
print "Got the slice credential, attempting to renew the sliver...";

params = {}
if extracred:
    params["credentials"]  = (slicecred,extracred)
else:
    params["credentials"]  = (slicecred,)
    pass
params["slice_urn"]    = myslice["urn"]
params["valid_until"]  = valid_until
rval,response = do_method("cm", "RenewSlice", params, version="2.0")
if rval:
    Fatal("Renewed slice, but not sliver.")
    pass
print "Sliver has been renewed until " + valid_until


