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
OtherUser = None

execfile( "test-common.py" )

if len(REQARGS) == 1:
    OtherUser = REQARGS[0]
    pass

#
# Get a credential for myself, that allows me to do things at the SA.
#
print "Obtaining SA credential...",
sys.stdout.flush()
mycredential = get_self_credential()
print " "

#
# Lookup slice, delete before proceeding.
#
params = {}
params["credential"] = mycredential
params["type"]       = "Slice"
params["hrn"]        = SLICENAME
print "Looking for existing slice...",
sys.stdout.flush()
rval,response = do_method("sa", "Resolve", params)
print " "
if rval == 0:
    print "Deleting previously registered slice";
    params = {}
    params["credential"] = mycredential
    params["type"]       = "Slice"
    params["hrn"]        = SLICENAME
    rval,response = do_method("sa", "Remove", params)
    if rval:
        Fatal("Could not remove slice record")
        pass
    pass

#
# Create a slice. 
#
print "Creating new slice called " + SLICENAME + "...",
sys.stdout.flush()
params = {}
params["credential"] = mycredential
params["type"]       = "Slice"
params["hrn"]        = SLICENAME
rval,response = do_method("sa", "Register", params)
print " "
if rval:
    Fatal("Could not get my slice")
    print str(rval)
    print str(response)
    pass
myslice = response["value"]
print "New slice created: " + SLICEURN
if debug: print str(myslice)

#
# Lookup another user so we can bind them to the slice.
#
if OtherUser:
    params = {}
    params["hrn"]       = OtherUser;
    params["credential"] = mycredential
    params["type"]       = "User"
    rval,response = do_method("sa", "Resolve", params)
    if rval:
        Fatal("Could not resolve other user")
        pass
    user = response["value"]
    print "Found other user record at the SA, binding to slice ..."
    
    #
    # And bind the user to the slice so that he can get his own cred.
    #
    params = {}
    params["urn"]        = user["urn"]
    params["credential"] = myslice
    rval,response = do_method("sa", "BindToSlice", params)
    if rval:
        Fatal("Could not bind other user to slice")
        pass
    binding = response["value"]
    print "Bound other user to slice at the SA"
    pass

