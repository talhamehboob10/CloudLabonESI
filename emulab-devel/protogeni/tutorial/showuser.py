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
from M2Crypto import X509

def Usage():
    print "usage: " + sys.argv[ 0 ] + " [option...] username"
    print """Options:
    -c file, --credentials=file       read self-credentials from file
                                          [default: query from SA]
    -d, --debug                       be verbose about XML methods invoked
    -f file, --certificate=file       read SSL certificate from file
                                          [default: ~/.ssl/encrypted.pem]
    -h, --help                        show options and usage
    -p file, --passphrase=file        read passphrase from file
                                          [default: ~/.ssl/password]
    -r file, --read-commands=file     specify additional configuration file"""

execfile( "test-common.py" )

if len( args ) != 1:
    Usage()
    sys.exit( 1 )

#
# Get a credential for myself, that allows me to do things at the SA.
#
print "Obtaining SA credential...",
sys.stdout.flush()
mycredential = get_self_credential()
print " "

#
# Lookup the user.
#
print "Looking up user...",
sys.stdout.flush()
params = {}
params["hrn"] = args[ 0 ]
params["credential"] = mycredential
params["type"]       = "User"
rval,response = do_method("sa", "Resolve", params)
print " "
if rval:
    Fatal("Could not resolve " + params[ "hrn" ] )

print "User record:"
print "    UID: " + response[ "value" ][ "uid" ]
print "    URN: " + response[ "value" ][ "urn" ]
print "    Name: " + response[ "value" ][ "name" ]
print "    E-mail: " + response[ "value" ][ "email" ]
print "    Slices: " + str( response[ "value" ][ "slices" ] )
