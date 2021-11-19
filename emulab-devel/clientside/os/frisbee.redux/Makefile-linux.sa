#
# Copyright (c) 2000-2018 University of Utah and the Flux Group.
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
# At least support MBR partitioning
#
WITH_MBR	= 1
WITH_GPT	= 1

# Set to 1 for "secure frisbee" support.  Requires openssl libraries.
WITH_CRYPTO	= 1
WITH_SIGNING	= 1

# 
# Makefile for the standalone version of frisbee.
# (Standalone meaning not part of the Netbed build environment.)
#
SBINDIR=/usr/local/sbin
BINDIR=	/usr/local/bin

IMAGEZIPDIR	= ../imagezip

SHAREDOBJS	= log.o network.o trace.o utils.o

PTHREADCFLAGS	= -D_THREAD_SAFE -pthread

# get 64-bit off_t and pread/pwrite protos
LINUXOPTS	= -D_FILE_OFFSET_BITS=64 -D_GNU_SOURCE \
		  -D_XOPEN_SOURCE=500 -D_BSD_SOURCE=1

#
# STATIC = yes|no|fail
#
# NOTE: with some newer Linux distros (at least Ubuntu14) we cannot build
# static with libcrypto as that library references the dynamic linker.
# So either choose not to set STATIC for dynamic binaries, or set
# STATIC=fail, in which case the crypto-requiring features are disabled.
#
STATIC		= yes

ifeq ($(STATIC),yes)
LINUXOPTS	+= -static
LDFLAGS		+= -static
endif

ifeq ($(STATIC),fail)
LINUXOPTS	+= -static
LDFLAGS		+= -static
WITH_CRYPTO	= 0
WITH_SIGNING	= 0
endif

CLIENTFLAGS	= $(CFLAGS)
CLIENTLIBS	= -lz -lrt $(PTHREADLIBS)
CLIENTOBJS	= client.o frisbee.o checksum.o disksize.o $(SHAREDOBJS)

SERVERFLAGS	= $(CFLAGS)
SERVERLIBS	= $(PTHREADLIBS)
SERVEROBJS	= server.o $(SHAREDOBJS)

# Master server based image uploader client
UPLOADFLAGS	= $(CFLAGS)
UPLOADLIBS	=
UPLOADOBJS	= upload.o uploadio.o log.o network.o utils.o

ifeq ($(WITH_CRYPTO),1)
IUZFLAGS	+= -DWITH_CRYPTO -DSIGN_CHECKSUM
IUZLIBS		+= -lcrypto
endif
ifeq ($(WITH_MBR),1)
IUZFLAGS	+= -DWITH_MBR -Imbr
CLIENTOBJS	+= $(IMAGEZIPDIR)/mbr/mbr.o
endif
ifeq ($(WITH_GPT),1)
IUZFLAGS	+= -DWITH_GPT -Igpt -Dcrc32=gpt_crc32 -DIMAGEZIP
CLIENTOBJS	+= $(IMAGEZIPDIR)/gpt/gpt.o $(IMAGEZIPDIR)/gpt/crc32.o $(IMAGEZIPDIR)/gpt/gpt_glue.o
endif

CFLAGS		= -O2 -g -Wall -fno-builtin-log \
		  $(PTHREADCFLAGS) $(LINUXOPTS) -DSTATS -DMASTER_SERVER
STRIP		?= strip

#
# Define this if your implementation of cond_vars works well
# ("works well" in this case means doesn't hang forever or burn up
# the CPU while in condwait).
#
CFLAGS		+= -DCONDVARS_WORK

#
# Define this to a non-zero value to enable recording of trace data
#
#CFLAGS		+= -DNEVENTS=25000

#
# Turn on client event handling
#
# Leave these commented out!
#
#CFLAGS		+= -DDOEVENTS
#CLIENTOBJS	+= event.o $(OBJDIR)/event/lib/event.o $(OBJDIR)/event/lib/util.o
#CLIENTLIBS	+= `elvin-config --libs vin4c`
#EVENTFLAGS	= $(CFLAGS) `elvin-config --cflags vin4c` -I$(TESTBED_SRCDIR)

all: frisbee frisupload frisbeed

frisbee: $(CLIENTOBJS)
	$(CC) $(LDFLAGS) $(CLIENTFLAGS) $(CLIENTOBJS) $(CLIENTLIBS) $(IUZLIBS) -o frisbee
	cp frisbee frisbee.debug
	$(STRIP) frisbee

frisupload: $(UPLOADOBJS)
	$(CC) $(LDFLAGS) $(UPLOADFLAGS) $(UPLOADOBJS) $(UPLOADLIBS) -o frisupload
	cp frisupload frisupload.debug
	$(STRIP) frisupload

frisbeed: $(SERVEROBJS)
	$(CC) $(LDFLAGS) $(SERVERFLAGS) $(SERVEROBJS) $(SERVERLIBS) -o frisbeed
	cp frisbeed frisbeed.debug
	$(STRIP) frisbeed


event.o:	$(SRCDIR)/event.c decls.h log.h event.h
	$(CC) $(EVENTFLAGS) -c event.c

$(IMAGEZIPDIR)/imageunzip.c: $(IMAGEZIPDIR)/imagehdr.h $(IMAGEZIPDIR)/queue.h

$(IMAGEZIPDIR)/disksize.c: $(IMAGEZIPDIR)/imagehdr.h $(IMAGEZIPDIR)/queue.h

disksize.o:	$(IMAGEZIPDIR)/disksize.c
	$(CC) -c $(CFLAGS) $(IUZFLAGS) -DFRISBEE -I$(IMAGEZIPDIR) -o disksize.o $<

frisbee.o:	$(IMAGEZIPDIR)/imageunzip.c
	$(CC) -c $(CFLAGS) $(IUZFLAGS) -DFRISBEE -I$(IMAGEZIPDIR) -o frisbee.o $<

checksum.o:	$(IMAGEZIPDIR)/checksum.c
	$(CC) -c $(CFLAGS) $(IUZFLAGS) -DFRISBEE -I$(IMAGEZIPDIR) -o checksum.o $<

client.o:	decls.h log.h utils.h trace.h
server.o:	decls.h log.h utils.h trace.h
log.o:		decls.h log.h
network.o:	decls.h utils.h
trace.o:	decls.h trace.h log.h

install:
	$(INSTALL) frisbee $(DESTDIR)$(BINDIR)/frisbee
	$(INSTALL) frisupload $(DESTDIR)$(BINDIR)/frisupload
	$(INSTALL) frisbeed $(DESTDIR)$(SBINDIR)/frisbeed

clean:
	rm -f *.o *.a frisbee frisupload frisbeed frisbee.debug frisupload.debug frisbeed.debug
