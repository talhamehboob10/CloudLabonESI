#!/usr/local/bin/python
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



import sys
import socket
import time

hostName = sys.argv[1]
serverPort = 5001

serverSocket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

serverSocket.bind((socket.gethostname(), serverPort))

while True:
    clientData, clientAddr = serverSocket.recvfrom(1024)
    print str(clientAddr[0]) + " " + str(clientAddr[1]) + " " + clientData
    currentTime = int(time.time()*1000)
    replyMessage = clientData + " " + str(currentTime - int(clientData.split()[1]))
    serverSocket.sendto(replyMessage, clientAddr)
