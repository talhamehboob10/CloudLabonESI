#
# Copyright (c) 2005-2006 University of Utah and the Flux Group.
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

CC=g++
LD=g++
CFLAGS= -Wall -c -g -I../DataqSDK_Linux/DataqSDK 
LDFLAGS=  #-L../DataqSDK_Linux/DataqSDK -ldataqsdk -lpthread
SOURCES= main.cpp powerMeasure.cpp exceptions.cpp
OBJS = main.o powerMeasure.o exceptions.o
EXECUTABLE=main



all: $(EXECUTABLE)
	
$(EXECUTABLE): $(OBJS)
	(cd ../DataqSDK_Linux/DataqSDK/ && $(MAKE) static)
	$(LD) $(LDFLAGS) $(OBJS) -o $(EXECUTABLE) -L../DataqSDK_Linux/DataqSDK -ldataqsdk -lpthread

%.o: %.cpp
	$(CC) $(CFLAGS) -c $<

#debug: $(SOURCES)
#	$(CC) $(LDFLAGS) $(SOURCES) -g -o $(EXECUTABLE) -L../DataqSDK_Linux/DataqSDK -ldataqsdk
	
clean:
	rm -f *.o $(EXECUTABLE) *stackdump
	(cd ../DataqSDK_Linux/DataqSDK/ && $(MAKE) clean)
