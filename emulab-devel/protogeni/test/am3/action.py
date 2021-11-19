#! /usr/bin/env python
#
# Copyright (c) 2012 University of Utah and the Flux Group.
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
import sys
import pwd
import getopt
import os
import time
import re

ACCEPTSLICENAME=1

debug    = 0
impotent = 1

execfile( "test-common.py" )

action = "geni_start"

if len(REQARGS) != 1:
    Usage()
    sys.exit( 1 )
elif len(REQARGS) == 1:
    action = REQARGS[0]

if action != "geni_start" and action != "geni_stop" and action != "geni_restart":
   Fatal("Invalid action. Must be one of: geni_start geni_stop geni_restart");

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
    Fatal("No such slice exists")
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
# Perform operational action on the sliver
#
print "Performing Operational Action " + action + " ..."
options = {}
cred = {}
cred["geni_type"] = "geni_sfa"
cred["geni_version"] = "2"
cred["geni_value"] = myslice
params = [[SLICEURN], [cred], action, options]

try:
    response = do_method("am/3.0", "PerformOperationalAction", params,
                         response_handler=geni_am_response_handler)
    print action + "'d the sliver"
    print str(response)
except xmlrpclib.Fault, e:
    Fatal("Could not perform action on sliver: %s" % (str(e)))
