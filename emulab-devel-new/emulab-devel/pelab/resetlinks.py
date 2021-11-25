#! /usr/bin/env python
#
# Copyright (c) 2006, 2007 University of Utah and the Flux Group.
# 
# {{{EMULAB-LICENSE
# 
# This file is part of the Emulab network testbed software.
# 
# This file is free software: you can redistribute it and/or modify it
# under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or (at
# your option) any later version.
# 
# This file is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public
# License for more details.
# 
# You should have received a copy of the GNU Affero General Public License
# along with this file.  If not, see <http://www.gnu.org/licenses/>.
# 
# }}}
#

#
# Little script to reset the traffic shaping parameters for all links. Much
# of the guts of this stolen from loghole.
# Does a full reset of all delay nodes in the experiment
#

import xmlrpclib
import re
import pwd
import sys
import os

prefix = "/usr/testbed"

TBPATH = os.path.join(prefix, "lib")
if TBPATH not in sys.path:
    sys.path.append(TBPATH)

#
# Get PID and EID
#
if len(sys.argv) != 3:
    print "Usage: resetlinks.py pid eid"
    sys.exit(1)

pid = sys.argv[1];
eid = sys.argv[2];

#
# Set up a connection to the XMLRPC server so that we can find out about the
# links in this experiment
#
try:
    pw = pwd.getpwuid(os.getuid())
    pass
except KeyError:
    sys.stderr.write("error: unknown user id %d" % os.getuid())
    sys.exit(2)
    pass

USER = pw.pw_name
HOME = pw.pw_dir

CERTIFICATE = os.path.join(HOME, ".ssl", "emulab.pem")

if not os.path.exists(CERTIFICATE):
    sys.stderr.write("error: missing emulab certificate: %s\n" %
                     CERTIFICATE)
    sys.exit(2)
    pass

from M2Crypto.m2xmlrpclib import SSL_Transport
from M2Crypto import SSL

URI = "https://" + "boss" + ":" + str(3069) + prefix

ctx = SSL.Context("sslv23")
ctx.load_cert(CERTIFICATE, CERTIFICATE)
ctx.set_verify(SSL.verify_none, 16)
ctx.set_allow_unknown_ca(0)

SERVER = xmlrpclib.ServerProxy(URI, SSL_Transport(ctx))
PACKAGE_VERSION = 0.1

#
# Make sure it's a real experiment
#
state_method = getattr(SERVER, "experiment.state")
state = state_method(PACKAGE_VERSION, { "proj" : pid, "exp" : eid })
if state["code"] != 0:
    print "Experiment is not in the correct state"
    sys.exit(1)

#
# Get a list of all delay nodes in the experiment
#
info_method = getattr(SERVER, "experiment.info")
nodes = info_method(PACKAGE_VERSION, { "proj" : pid, "exp" : eid, "aspect" : "mapping" })
nodelist = nodes["value"]

delaynodes = list()
delayre = re.compile('tbs?delay\d+')
for node in nodelist:
    if delayre.match(node):
        delaynodes.append(node)

#
# ssh into each delay node and reset the firewall rules
#
for node in delaynodes:
    print "##### Cleaning %s" % node
    os.system("ssh -o 'BatchMode=yes' -o 'StrictHostKeyChecking=no' %s.%s.%s sudo /usr/local/etc/emulab/delaysetup -r" % (node,eid,pid))
