#! /usr/bin/env python
#
# Copyright (c) 2012-2014 University of Utah and the Flux Group.
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
import xmlrpclib

def Usage():
    print "usage: " + sys.argv[ 0 ] + " [option...] <public|private|identifying> <user_urn [...]>"
    print """Options:
    -d, --debug                         be verbose about XML methods invoked
    -h, --help                          show options and usage
    -r file, --read-commands=file       specify additional configuration file"""

execfile( "test-common.py" )

authority = "geni-ma"

callargs = [
    [{
      'geni_type': 'geni_sfa',
      'geni_version': '3',
      'geni_value': get_self_credential()}],
     {
     }
    ]

try:
    response = do_method(authority, "lookup_keys",
                         callargs,
                         response_handler=geni_am_response_handler)
    print response
except xmlrpclib.Fault, e:
    Fatal("Could not obtain keys: %s" % (str(e)))
