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

ACCEPTSLICENAME=1

debug    = 0
impotent = 0
dokeys   = 1

execfile( "test-common.py" )

#
# Get a credential for myself, that allows me to do things at the SA.
#
mycredential = get_self_credential()
print "Got my SA credential"

ticket = "";
if len(REQARGS) == 1:
  try:
    ticketfile = open(REQARGS[0])
    ticket = ticketfile.read()
    ticketfile.close()
  except IOError, e:
    print >> sys.stderr, args[0] + ": " + e.strerror
    sys.exit(1)

#
# Lookup my ssh keys.
#
if dokeys:
  params = {}
  params["credential"] = mycredential
  params["version"]    = 2
  rval,response = do_method("sa", "GetKeys", params)
  if rval:
    Fatal("Could not get my keys")
    pass
  mykeys = response["value"]
  if debug: print str(mykeys)
  pass

#
# Lookup slice and get credential.
#
myslice = resolve_slice( SLICENAME, mycredential )

#
# Get the slice credential.
#
print "Asking for slice credential for " + SLICENAME
slicecred = get_slice_credential( myslice, mycredential )
print "Got the slice credential"

if ticket == "":
  #
  # Do a resolve to get the ticket urn.
  #
  print "Resolving the slice at the CM"
  params = {}
  params["credentials"] = (slicecred,)
  params["urn"]         = myslice["urn"]
  rval,response = do_method("cm", "Resolve", params, version="2.0")
  if rval:
    Fatal("Could not resolve slice")
    pass
  mysliver = response["value"]
  print str(mysliver)

  if not "ticket_urn" in mysliver:
    Fatal("No ticket exists for slice")
    pass

  #
  # Get the ticket with another call to resolve.
  #
  print "Asking for a copy of the ticket"
  params = {}
  params["credentials"] = (slicecred,)
  params["urn"]         = mysliver["ticket_urn"]
  rval,response = do_method("cm", "Resolve", params, version="2.0")
  if rval:
    Fatal("Could not get the ticket")
    pass
  ticket = response["value"]
  print "Got the ticket"

redeemcred = slicecred;
#
# Get the sliver credential.
#
print "Asking for sliver credential"
params = {}
params["slice_urn"]   = myslice["urn"]
params["credentials"] = (slicecred,)
rval,response = do_method("cm", "GetSliver", params, version="2.0")
if not rval:
   redeemcred = response["value"]
   print "Got the sliver credential"

#
# And redeem the ticket.
#
print "Redeeming the ticket"
params = {}
params["credentials"] = (redeemcred,)
params["ticket"]      = ticket
params["slice_urn"]   = myslice["urn"]
if dokeys:
  params["keys"]        = mykeys
  pass
rval,response = do_method("cm", "RedeemTicket", params, version="2.0")
if rval:
    Fatal("Could not redeem the ticket")
    pass
(sliver, manifest) = response["value"]
print "Created the sliver"
print str(manifest)
