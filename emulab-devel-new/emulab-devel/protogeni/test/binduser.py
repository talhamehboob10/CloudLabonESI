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
import xmlrpclib

ACCEPTSLICENAME=1
dokeys   = 1
amapiv3  = 0
cancel   = 0

execfile( "test-common.py" )

#
# Get a credential for myself, that allows me to do things at the SA.
#
mycredential = get_self_credential()
print "Got self credential"

#
# Lookup slice.
#
myslice = resolve_slice( SLICENAME, mycredential )
print "Resolved slice " + myslice["urn"]

#
# Get the slice credential.
#
slicecredential = get_slice_credential( myslice, mycredential )
print "Got slice credential"

#
# Lookup my ssh keys.
#
if dokeys:
    params = {}
    params["credential"] = mycredential
    rval,response = do_method("sa", "GetKeys", params)
    if rval:
        Fatal("Could not get my keys")
        pass
    mykeys = response["value"]
    if debug: print str(mykeys)
    pass

#
# Bind to slice at the CM.
#
if amapiv3:
    #
    # Convert keys to AM style.
    #
    keys = []
    for key in mykeys:
        keys.append(key['key'])
        pass
    mykeys = {'urn' : 'urn:publicid:IDN+emulab.net+user+testuser',
              'keys': keys }
    options = {}
    options["geni_users"] = [ mykeys ]
    cred = {}
    cred["geni_type"] = "geni_sfa"
    cred["geni_version"] = "2"
    cred["geni_value"] = slicecredential
    params = [[SLICEURN], [cred], "geni_update_users" , options]
    try:
        response = do_method("am/3.0", "PerformOperationalAction", params,
                             response_handler=geni_am_response_handler)
        pass
    except xmlrpclib.Fault, e:
        Fatal("Could not bind myself to slice: %s" % (str(e)))
        pass
    pass
else:
    params = {}
    params["credentials"] = (slicecredential,)
    params["slice_urn"]   = myslice["urn"]
    params["keys"]        = mykeys
    rval,response = do_method("cm", "BindToSlice", params, version="2.0")
    if rval:
        Fatal("Could not bind myself to slice")
        pass
    pass
print "Bound myself to slice"

if amapiv3 and cancel:
    print "Canceling update ... just testing if it works."
    options = {}
    cred = {}
    cred["geni_type"] = "geni_sfa"
    cred["geni_version"] = "2"
    cred["geni_value"] = slicecredential
    params = [[SLICEURN], [cred], "geni_update_users_cancel" , options]
    try:
        response = do_method("am/3.0", "PerformOperationalAction", params,
                             response_handler=geni_am_response_handler)
        pass
    except xmlrpclib.Fault, e:
        Fatal("Could not cancel account update: %s" % (str(e)))
        pass
    print "Update canceled"
    pass
