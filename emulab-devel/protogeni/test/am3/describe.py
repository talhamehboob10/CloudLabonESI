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
import sys
import pwd
import getopt
import os
import re
import zlib

execfile( "test-common.py" )

#
# Get a credential for myself, that allows me to do things at the SA.
#
mycredential = get_self_credential()

#
# Lookup slice
#
myslice = resolve_slice( SLICENAME, mycredential )
print "Found the slice, asking for a credential ..."

#
# Get the slice credential.
#
slicecred = get_slice_credential( myslice, mycredential )
print "Got the slice credential, asking for description at the CM ..."

#
# Ask manager for its list.
#
options = {}
cred = {}
cred["geni_type"] = "geni_sfa"
cred["geni_version"] = "2"
cred["geni_value"] = slicecred
params = [[SLICEURN], [cred], options]

try:
    response = do_method("am/3.0", "Describe", params,
                         response_handler=geni_am_response_handler)
    print response
except xmlrpclib.Fault, e:
    Fatal("Could not get a description of slivers: %s" % (str(e)))

