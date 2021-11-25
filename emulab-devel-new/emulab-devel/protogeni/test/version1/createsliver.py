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
import xmlrpclib

ACCEPTSLICENAME=1

def Usage():
    print "usage: " + sys.argv[ 0 ] + " [option...] [resource-specification]"
    print """Options:
    -c file, --credentials=file         read self-credentials from file
                                            [default: query from SA]
    -d, --debug                         be verbose about XML methods invoked
    -f file, --certificate=file         read SSL certificate from file
                                            [default: ~/.ssl/encrypted.pem]
    -h, --help                          show options and usage
    -k keyfile, --keys=keyfile          read SSH keys from file            
                                            [default: query from SA]
    -n name, --slicename=name           specify human-readable name of slice
                                            [default: mytestslice]
    -p file, --passphrase=file          read passphrase from file
                                            [default: ~/.ssl/password]
    -r file, --read-commands=file       specify additional configuration file
    -s file, --slicecredentials=file    read slice credentials from file
                                            [default: query from SA]
    -u, --update                        perform an update after creation"""

update = False
# We're supposed to make a temporary copy of a list to iterate over it
# if we might also mutate it.  Silly Python.
for arg in sys.argv[:]:
    if arg == "-u" or ( len( arg ) >= 3 and "--update".find( arg ) == 0 ):
        sys.argv.remove( arg )
        update = True

# Gah.  This case is even uglier, since we need to remove both the
# option and its mandator parameter.  Don't bother addressing the
# case where the user specifies -k more than once: they are being silly.
keyfile = ""
for i in range( len( sys.argv ) ):
    if sys.argv[ i ] == "-k" or ( len( sys.argv[ i ] ) >= 3 and "--key".find( sys.argv[ i ] ) == 0 ):
        if i + 1 >= len( sys.argv ):
            Usage()
            sys.exit( 1 )
        keyfile = sys.argv[ i + 1 ]
        sys.argv[ i : i + 2 ] = [];
        break

execfile( "test-common.py" )

if len( args ) > 1:
    Usage()
    sys.exit( 1 )
elif len( args ) == 1:
    try:
        rspecfile = open( args[ 0 ] )
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
mycredential = get_self_credential()
print "Got my SA credential"

#
# Lookup my ssh keys.
#
params = {}
params["credential"] = mycredential
if keyfile == "":
    rval,response = do_method("sa", "GetKeys", params)
    if rval:
        Fatal("Could not get my keys")
        pass
    mykeys = response["value"]
else:
    mykeys = []
    f = open( keyfile )
    for keyline in f:
        if re.match( r"\s*#", keyline ):
            continue
        mykeys.append( { 'type' : 'ssh', 'key' : keyline } )
    f.close()
if debug: print str(mykeys)

#
# Lookup slice.
#
params = {}
params["credential"] = mycredential
params["type"]       = "Slice"
params["hrn"]        = SLICENAME
rval,response = do_method("sa", "Resolve", params)
if rval:
    #
    # Create a slice. 
    #
    print "Creating new slice called " + SLICENAME
    params = {}
    params["credential"] = mycredential
    params["type"]       = "Slice"
    params["hrn"]        = SLICENAME
    rval,response = do_method("sa", "Register", params)
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
    print "Asking for slice credential for " + SLICENAME
    myslice = response["value"]
    myslice = get_slice_credential( myslice, mycredential )
    print "Got the slice credential"
    pass

#
# Get a ticket. We do not have a real resource discovery tool yet, so
# as a debugging aid, you can wildcard the uuid, and the CM will find
# a free node and fill it in.
#
print "Asking for a ticket from the CM"

params = {}
params["credential"] = myslice
params["rspec"]      = rspec
rval,response = do_method("cm", "GetTicket", params)
if rval:
    if response and response["value"]:
        print >> sys.stderr, ""
        print >> sys.stderr, str(response["value"])
        print >> sys.stderr, ""
        pass
    Fatal("Could not get ticket")
    pass
ticket = response["value"]
print "Got a ticket from the CM. Redeeming the ticket ..."

#
# Create the sliver.
#
params = {}
params["credential"] = myslice
params["ticket"]   = ticket
params["keys"]     = mykeys
params["impotent"] = impotent
rval,response = do_method("cm", "RedeemTicket", params)
if rval:
    Fatal("Could not redeem ticket")
    pass
sliver,manifest = response["value"]
print "Created the sliver"
print str(manifest)

if update:
    #
    # Get an updated ticket using the manifest. Normally the user would
    # actually change the contents.
    #
    print "Updating the original ticket ..."
    params = {}
    params["credential"] = myslice
    params["ticket"]     = ticket
    params["rspec"]      = manifest
    rval,response = do_method("cm", "UpdateTicket", params)
    if rval:
        Fatal("Could not update the ticket")
        pass
    newticket = response["value"]
    print "Got an updated ticket from the CM. Updating the sliver ..."

    #
    # Update the sliver
    #
    params = {}
    params["credential"] = sliver
    params["ticket"]     = newticket
    rval,response = do_method("cm", "UpdateSliver", params)
    if rval:
        Fatal("Could not update sliver on CM")
        pass
    manifest = response["value"]
    print "Updated the sliver on the CM, asking for a ticket copy ..."
    print str(manifest)

#
# Grab a sliver ticket just for the hell of it.
#
params = {}
params["credential"] = sliver
rval,response = do_method("cm", "SliverTicket", params)
if rval:
    Fatal("Could not get sliver ticket/manifest")
    pass
print "Got a new ticket"
ticket = response["value"]
print str(ticket);

print ""
print "Start this sliver with startsliver.py"
print "Delete this sliver with deletesliver.py"
