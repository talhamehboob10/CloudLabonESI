#! /usr/local/bin/python
#
# Copyright (c) 2002-2004 University of Utah and the Flux Group.
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

import sys
import getopt

sys.path.append("/test/lib")

from tbevent import *

# Usage message
usage = """Example python testbed event sender.
Usage: tbsend.py [-h] [-s server] [-p port] <event>

Optional arguments:
  -h       Print this message.
  -s name  The host name where the elvin event server is located.
           (Default: boss)
  -p port  The port the elvin event server is listening on.

Example:
  $ tbsend.py FOO
"""

# Default values
server = "boss"
port = ""

# Process command line arguments
try:
    opts, args = getopt.getopt(sys.argv[1:],
                               "hs:p:",
                               [ "help",
                                 "server=",
                                 "port=" ])
    for opt, val in opts:
        if opt in ("-h", "--help"):
            sys.stderr.write(usage)
            sys.exit()
            pass
        elif opt in ("-s", "--server"):
            server = val
            pass
        elif opt in ("-p", "--port"):
            port = val
            pass
        else:
            sys.stderr.write("Unhandled option: " + opt + "\n")
            pass
        pass
    if len(args) == 0:
        sys.stderr.write(usage)
        sys.exit(2)
        pass
    pass
except getopt.error:
    sys.stderr.write(usage)
    sys.exit(2)
    pass

#
# Allocate and initialize an address tuple like any other python object, there
# is no need to use address_tuple_alloc().
#
at = address_tuple()
at.host = ADDRESSTUPLE_ALL
at.objtype = "TBEXAMPLE"
at.eventtype = sys.argv[1].upper() # XXX Uppercase everything...

# Construct a regular client,
ec = EventClient(server=server, port=port)
# ... create our notification, and
en = ec.create_notification(at)
# ... send it off.
ec.notify(en)
