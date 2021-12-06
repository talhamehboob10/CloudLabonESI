#! /usr/local/bin/python

import sys
import time
sys.path.append("/usr/testbed/lib")

from tbevent import *

server   = "event-server"
port     = None
keyfile  = "/proj/emulab-ops/exp/one-node/tbdata/eventkey"

# Construct a regular client. Do this only once.
ec = EventClient(server=server, port=port, url=None, keyfile=keyfile)

#
# Allocate and initialize an address tuple like any other python object.
# You can reuse this tuple.
#
at = address_tuple()
at.objname   = "link0"
at.eventtype = "modify"
at.expt      = "emulab-ops/one-node"

# ... create our notification from the tuple.
note = ec.create_notification(at)

# Add extra arguments to the notification.
note.setArguments("bandwith=1000 delay=13");

# Schedule the notification for right now.
tval = timeval();
tval.tv_sec  = long(time.time())
tval.tv_usec = 0;

# And Fire it.
ec.schedule(note, tval)

# Delete the notification.
del note
