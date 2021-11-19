#! /usr/bin/env python
#
# Copyright (c) 2009-2010 University of Utah and the Flux Group.
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

execfile("test-common.py")

HRN = None
TYPE = None
if len(REQARGS) == 2:
    HRN = REQARGS[0]
    TYPE = REQARGS[1]
else:
    print "You must supply a HRN and TYPE to resolve"
    sys.exit(1)
    pass

# sanity check on specified type
if TYPE not in ["SA", "CM", "Component", "Slice", "User"]:
    print "TYPE must be one of SA|CM|Component|Slice|User"
    sys.exit(1)

#
# Get special credentials from the command line, that allows me to do things
# at the CH. 
#
if not selfcredentialfile:
    print "Please specify special credentials with -c option."
    sys.exit(1)

mycredential = get_self_credential()

print "Resolving at the CH"
params = {}
params["credential"] = mycredential
params["hrn"]        = HRN
params["type"]       = TYPE
rval,response = do_method("ch", "Resolve", params, version="2.0")
if rval:
    Fatal("Could not resolve")
    pass
value = response["value"]
print str(value)


