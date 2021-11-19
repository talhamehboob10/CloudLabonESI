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
import re
import xmlrpclib
from M2Crypto import X509

ACCEPTSLICENAME=1

execfile( "test-common.py" )

if len(REQARGS) != 1 or REQARGS[0] != "verified":
    print "Are you sure you want to use this script? It freezes the slice."
    print "You probably want to use deleteslice.py instead."
    print "If you really want to use this script, add 'verified'"
    sys.exit(1)
    pass

#
# Get a credential for myself, that allows me to do things at the SA.
#
mycredential = get_self_credential()
print "Got my SA credential"

#
# Lookup slice, get credential.
#
myslice = resolve_slice( SLICENAME, mycredential )
myslice = get_slice_credential( myslice, mycredential )
print "Got the slice credential"

print "Shutting down slice";
params = {}
params["credential"] = myslice
rval,response = do_method("sa", "Shutdown", params)
if rval:
    Fatal("Could not shutdown slice")
    pass
print "Slice has been shutdown";
