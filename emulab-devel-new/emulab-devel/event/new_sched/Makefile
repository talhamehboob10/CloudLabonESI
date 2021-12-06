#
# Copyright (c) 2002, 2011 University of Utah and the Flux Group.
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
# Makefile for building event scheduler
#
# $Id: Makefile,v 1.5 2006-12-01 22:59:37 mike Exp $

CC		= gcc
CFLAGS		= -g -I. -I../../lib/event -Wall -DDEBUG
LDFLAGS		=
LIBS		= -lpthread -L../../lib/event -levent

CFLAGS         += `elvin-config --cflags vin4mt`
LIBS           += `elvin-config --libs vin4mt`

MV		= mv -f
RM		= rm -f

program		= event-sched
source		= event-sched.c queue.c
object		= event-sched.o queue.o
header		= event-sched.h

.c.o:
	$(CC) $(CFLAGS) -c $<

default: $(program)

$(program): $(object)
	$(CC) $(LDFLAGS) -o $@ $^ $(LIBS) $(LIBS)

$(program): ../../lib/event/libevent.a

$(object): $(header) ../../lib/event/event.h

clean:
	$(RM) $(program) $(object)
