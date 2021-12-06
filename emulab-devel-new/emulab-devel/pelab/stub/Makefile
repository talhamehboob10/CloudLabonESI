#
# Copyright (c) 2006 University of Utah and the Flux Group.
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
all: stubd stub-monitor dumb-client dumb-server

stubd: stubd.o stub-pcap.o lookup.o log.o
	g++ -I. -g -Wall stubd.o stub-pcap.o lookup.o log.o -lm -lpcap -o stubd
stub-monitor: stub-monitor.c stub.h
	gcc -I. -g -Wall stub-monitor.c -o stub-monitor
stubd.o: stubd.c stub.h log.h
	gcc -I. -g -Wall -c stubd.c 
stub-pcap.o: stub-pcap.c stub.h log.h
	gcc -I. -g -Wall -c stub-pcap.c
lookup.o: lookup.cc stub.h log.h
	g++ -I. -g -Wall -c lookup.cc
log.o: log.c log.h
	gcc -I. -g -Wall -c log.c
dumb-client: dumb-client.o
	gcc -I. -g -Wall dumb-client.o -lm -lpcap -o dumb-client
dumb-client.o: dumb-client.c stub.h
	gcc -I. -g -Wall -c dumb-client.c
dumb-server: dumb-server.o
	gcc -I. -g -Wall dumb-server.o -lm -lpcap -o dumb-server
dumb-server.o: dumb-server.c stub.h
	gcc -I. -g -Wall -c dumb-server.c

clean:
	rm *.o stubd stubm stub-monitor 
