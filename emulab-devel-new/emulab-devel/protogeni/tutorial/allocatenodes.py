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
import time
import re
import xml.dom.minidom

ACCEPTSLICENAME=1

debug    = 0
impotent = 1

execfile( "test-common.py" )

if len(REQARGS) > 1:
    Usage()
    sys.exit( 1 )
elif len(REQARGS) == 1:
    try:
        rspecfile = open(REQARGS[0])
        rspec = rspecfile.read()
        rspecfile.close()
    except IOError, e:
        print >> sys.stderr, args[ 0 ] + ": " + e.strerror
        sys.exit( 1 )
else:
    rspec = "<rspec xmlns=\"http://protogeni.net/resources/rspec/0.1\"> " +\
            " <node virtual_id=\"geni1\" "+\
            "       virtualization_type=\"emulab-vnode\" " +\
            "       startup_command=\"/bin/ls > /tmp/foo\"> " +\
            " </node>" +\
            "</rspec>"    

#
# Get a credential for myself, that allows me to do things at the SA.
#
print "Obtaining SA credential...",
sys.stdout.flush()
mycredential = get_self_credential()
print " "

#
# Lookup my ssh keys.
#
params = {}
params["credential"] = mycredential
print "Looking up SSH keys...",
sys.stdout.flush()
rval,response = do_method("sa", "GetKeys", params)
print " "
if rval:
    Fatal("Could not get my keys")
    pass
mykeys = response["value"]
if debug: print str(mykeys)
keyfile = open( os.environ[ "HOME" ] + "/.ssh/id_rsa.pub" )
emulabkey = keyfile.readline().strip()
keyfile.close()
mykeys.append( { 'type' : 'ssh', 'key' : emulabkey } )
if debug: print str(mykeys)

#
# Lookup slice.
#
params = {}
params["credential"] = mycredential
params["type"]       = "Slice"
params["hrn"]        = SLICENAME
print "Looking up slice...",
sys.stdout.flush()
rval,response = do_method("sa", "Resolve", params)
print " "
if rval:
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
        Fatal("Could not create new slice")
        pass
    myslice = response["value"]
    print "New slice created"
    pass
else:
    #
    # Get the slice credential.
    #
    print "Asking for slice credential for " + SLICENAME + "...",
    sys.stdout.flush()
    myslice = response["value"]
    myslice = get_slice_credential( myslice, mycredential )
    print " "
    pass

#
# Create the sliver.
#
print "Creating the sliver...",
sys.stdout.flush()
params = {}
params["credentials"] = (myslice,)
params["slice_urn"]   = SLICEURN
params["rspec"]       = rspec
params["keys"]        = mykeys
params["impotent"]    = impotent
rval,response = do_method("cm", "CreateSliver", params, version="2.0")
print " "
if rval:
    Fatal("Could not create sliver")
    pass
sliver,manifest = response["value"]
print "Received the manifest:"

doc = xml.dom.minidom.parseString( manifest )

for node in doc.getElementsByTagName( "node" ):
    print "    Node " + node.getAttribute( "virtual_id" ) + " is " + node.getAttribute( "hostname" )

print "Waiting until sliver is ready",
sys.stdout.flush()

#
# Poll for the sliver status.  It would be nice to use WaitForStatus
# here, but SliverStatus is more general (since it falls in the minimal
# subset).
#
params = {}
params["slice_urn"]   = SLICEURN
params["credentials"] = (sliver,)
while True:
    rval,response = do_method("cm", "SliverStatus", params, quiet=True, version="2.0")
    if rval:
        sys.stdout.write( "*" )
        sys.stdout.flush()
	time.sleep( 3 )
    elif response[ "value" ][ "status" ] == "ready":
        break
    elif response[ "value" ][ "status" ] == "changing" or response[ "value" ][ "status" ] == "mixed":
        sys.stdout.write( "." )
        sys.stdout.flush()
        time.sleep( 3 )
    else:
	print
        Fatal( "Sliver status is " + response[ "value" ][ "status" ] )

print
print "Sliver is ready."
