#! /usr/bin/env python
#
# Copyright (c) 2008-2009 University of Utah and the Flux Group.
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

execfile( "test-common.py" )

TYPE = None

if len(REQARGS) == 1:
    TYPE = REQARGS[0]
else:
    print "You must supply a TYPE (users|slices|authorities) to list"
    sys.exit(1)
    pass

# sanity check on TYPE
if TYPE not in ["users", "slices", "authorities"]:
    print "TYPE must be one of users|slices|authorities"
    sys.exit(1)

#
# Get a credential for myself, that allows me to do things at the SA.
#
mycredential = get_self_credential()

#
# Ask the clearinghouse for a list of users|slices|authorities as specified
# by TYPE
params = {}
params["credential"] = mycredential
params["type"]       = TYPE
rval,response = do_method("ch", "List", params)
if rval:
    Fatal("Could not get the list from the ClearingHouse")
    pass
print str(response["value"])

