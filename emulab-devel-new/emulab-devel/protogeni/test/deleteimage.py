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

debug    = 0
impotent = 1
doglobal = 1

def Usage():
    print "usage: " + sys.argv[ 0 ] + " [option...] image_urn [creator_urn]"
    print "Options:"
    BaseOptions()
    pass

execfile( "test-common.py" )

if len(REQARGS) < 1 or len(REQARGS) > 2:
    Usage()
    sys.exit(1)
    pass

imageurn  = REQARGS[0]

#
# Get a credential for myself, that allows me to do things at the SA.
#
mycredential = get_self_credential()
print "Got my SA credential"

#
# Delete the image
#
print "Deleting the Image ..."
params = {}
params["credentials"] = (mycredential,)
params["image_urn"]   = imageurn
if len(REQARGS) == 2:
    params["creator_urn"]   = REQARGS[1]
    pass
rval,response = do_method("cm", "DeleteImage", params, version="2.0")
if rval:
    Fatal("Could not delete image")
    pass
