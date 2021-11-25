#! /usr/bin/env python
#
# Copyright (c) 2008-2014 University of Utah and the Flux Group.
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

ACCEPTSLICENAME=1
URN = None

execfile( "test-common.py" )

if len(REQARGS) < 1:
    print >> sys.stderr, "Must provide the action (start/stop/restart)"
    sys.exit(1)
else:
    action = REQARGS[0]
    if (action != "start" and action != "stop" and
        action != "restart" and action != "reload"):
        print >> sys.stderr, "Action must be one of start/stop/restart/reload"
        sys.exit(1)
        pass
    if len(REQARGS) == 2:
        URN = REQARGS[1]
        pass
    pass

#
# Get a credential for myself, that allows me to do things at the SA.
#
mycredential = get_self_credential()
print "Got my SA credential. Looking for slice ..."

#
# Lookup slice, delete before proceeding.
#
myslice = resolve_slice( SLICENAME, mycredential )
print "Found the slice, asking for a credential ..."

if admincredentialfile:
  f = open( admincredentialfile )
  slivercred = f.read()
  f.close()
else:
  #
  # Get the slice credential.
  #
  slicecred = get_slice_credential( myslice, mycredential )
  print "Got the slice credential, asking for a sliver credential ..."

  #
  # Get the sliver credential.
  #
  params = {}
  params["credentials"] = (slicecred,)
  params["slice_urn"]   = myslice["urn"]
  rval,response = do_method("cm", "GetSliver", params, version="2.0")
  if rval:
    Fatal("Could not get Sliver credential")
    pass
  slivercred = response["value"]

if action == "start":
    method = "StartSliver"
elif action == "stop":
    method = "StopSliver"
elif action == "reload":
    method = "ReloadSliver"
else:
    method = "RestartSliver"
    pass

#
# Start the sliver.
#
print "Got the sliver credential, calling " + method + " on the sliver";
params = {}
params["credentials"] = (slivercred,)
if URN:
    params["component_urns"] = (URN,)
else:
    params["slice_urn"] = myslice["urn"]
    pass
rval,response = do_method("cm", method, params, version="2.0")
if rval:
    Fatal("Could not start sliver")
    pass
print "Sliver has been " + action + "'ed."



