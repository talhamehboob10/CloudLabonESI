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
SRCDIR		= ../../../../clientside/os/imagezip
TESTBED_SRCDIR	= ../../../..
OBJDIR		= ../../..
SUBDIR		= $(subst $(TESTBED_SRCDIR)/,,$(SRCDIR))

DISTFILES	= global.h imagehdr.h queue.h sliceinfo.h \
		  imagedump.c imagedump.8 imagezip.c imagezip.8 \
		  imageunzip.c crc.c checksum.c disksize.c imageunzip.8 \
		  mbr/*.[hc] gpt/*.[hc] \
		  extfs/*.[hc] fat/*.[hc] ffs/*.[hc] \
		  ntfs/*.[hc] hashmap/*.[hc]

EXPANDCOPYRIGHT	= /usr/site/lib/copyright/expand-copyr

WITH_RANGEMAP	= 0

#
# At least support MBR partitioning
#
WITH_MBR	= 1
WITH_GPT	= 1

#
# Support disk erase (e.g., TRIM) operations
# (incomplete as of 1/2016)
#
WITH_ERASE	= 0

#
# Support encrypted and signed-checksumed images.
# Requires openssl libraries.
#
WITH_CRYPTO	= 1
WITH_SIGNING	= 1

#
# Support for auto-generation of old image versions
#
WITH_V3COMPAT	= 1
 
SYSTEM	:= $(shell uname -s)

# FreeBSD specific goop
ifeq ($(SYSTEM),FreeBSD)
FBSDREL	:= $(shell uname -r | sed -e 's/\([^-][^-]*\)-.*/\1/')
FBSDMAJ := $(basename $(FBSDREL))

# FreeBSD 5 has GCC3 and LOCALE
# XXX this should be done with configure
ifneq ($(FBSDMAJ),4)
export HAVE_GCC3 = 1
export HAVE_LOCALE = 1
endif

WITH_LTHREADS	= 0

ifeq ($(FBSDMAJ),4)
WITH_LTHREADS	= 1
endif
ifeq ($(FBSDMAJ),5)
# XXX 5.3 and linuxthreads don't see to get along
ifneq ($(FBSDREL),5.3)
WITH_LTHREADS	= 1
endif
endif
ifeq ($(FBSDMAJ),6)
WITH_LTHREADS	= 1
endif
endif

# Linux specific goop
ifeq ($(SYSTEM),Linux)

# XXX this should be done with configure
export LINUX = 1
export HAVE_GCC3 = 1
export HAVE_LOCALE = 1

endif

#
# Support for various filesystems
#
WITH_FFS	= 1
WITH_EXTFS	= 1
WITH_NTFS	= 0
WITH_FAT	= 0

# Note: requires WITH_CRYPTO
WITH_HASH	= 1
WITH_HASHALIGN	= 0

include $(OBJDIR)/Makeconf

SUBDIRCFLAGS	= -Wall -g -O2 # -ansi -pedantic
ifeq ($(SYSTEM),Linux)
SUBDIRCFLAGS	+= -D_FILE_OFFSET_BITS=64 -D_GNU_SOURCE -D_THREAD_SAFE -DCONDVARS_WORK -pthread
else
ifeq ($(WITH_LTHREADS),1)
PTHREADCFLAGS	= -D_THREAD_SAFE -I/usr/local/include/pthread/linuxthreads
PTHREADLIBS	= -L/usr/local/lib -llthread -llgcc_r
else
PTHREADCFLAGS	= -D_THREAD_SAFE -DCONDVARS_WORK
PTHREADLIBS	= -lpthread
endif
SUBDIRCFLAGS	+= 
endif

# Define this if you implementation of cond_vars works well
# They don't with linuxthreads under FreeBSD: wakeups take longer than
# Necessary sometimes.
#PTHREADCFLAGS	+= -DCONDVARS_WORK

PROGS		= imagezip imageunzip imagedump imagerezip imagedelta imageundelta
CFLAGS		= $(SUBDIRCFLAGS) -I$(SRCDIR) $(LDSTATIC)
LIBS 		= -lz
ZIPCFLAGS	= $(CFLAGS) -Wall
ZIPLIBS		= 
UNZIPCFLAGS	= $(CFLAGS) $(PTHREADCFLAGS) -Wall
UNZIPLIBS	= $(LIBS) $(PTHREADLIBS)
UNZIPDIRS	=
HASHCFLAGS	= $(CFLAGS) $(PTHREADCFLAGS) -Wall
HASHLIBS	= $(LIBS) -lcrypto $(PTHREADLIBS)
NDZLIBS		= libndz/libndz.a $(LIBS)

# Secure images
ifeq ($(WITH_CRYPTO),1)
PROGS		+= imagehash
CFLAGS		+= -DWITH_CRYPTO
ifeq ($(WITH_SIGNING),1)
CFLAGS		+= -DSIGN_CHECKSUM
endif
LIBS		+= -lcrypto
endif

# Support generation of V3 images when "secure" features not used
ifeq ($(WITH_V3COMPAT),1)
CFLAGS		+= -DWITH_V3COMPAT
endif

SUBDIRS		+= libndz

# MBR
ifeq ($(WITH_MBR),1)
CFLAGS		+= -DWITH_MBR
SUBDIRS		+= mbr
UNZIPDIRS	+= mbr
ZIPLIBS		+= mbr/libmbr.a
UNZIPLIBS	+= mbr/libmbr.a
endif

# GPT
ifeq ($(WITH_GPT),1)
CFLAGS		+= -DWITH_GPT
SUBDIRS		+= gpt
UNZIPDIRS	+= gpt
ZIPLIBS		+= gpt/libgpt.a
UNZIPLIBS	+= gpt/libgpt.a
endif

# UFS/UFS2
ifeq ($(WITH_FFS),1)
CFLAGS		+= -DWITH_FFS
SUBDIRS		+= ffs
ZIPLIBS		+= ffs/libffs.a
endif

# EXT2/EXT3
ifeq ($(WITH_EXTFS),1)
CFLAGS		+= -DWITH_EXTFS
SUBDIRS		+= extfs
ZIPLIBS		+= extfs/libextfs.a
endif

# with NTFS
ifeq ($(WITH_NTFS),1)
ifndef HAVE_GCC3
CC		= gcc30
endif

#
# Default to the "lastest" libntfs (2.0.0).
# If there are problems, switch back to:
# NTFSVER		= 1.7.1
#
ifndef NTFSVER
NTFSVER		= 2.0.0
endif
export		NTFSVER

CFLAGS		+= -DWITH_NTFS
SUBDIRS		+= ntfs
ZIPLIBS		+= ntfs/libntfs.a
ifndef HAVE_LOCALE
ZIPLIBS		+= ntfs/liblocale.a
endif
endif

# with FAT
ifeq ($(WITH_FAT),1)
CFLAGS		+= -DWITH_FAT
SUBDIRS		+= fat
ZIPLIBS		+= fat/libfat.a
endif

# with HASH
ifeq ($(WITH_HASH),1)
CFLAGS		+= -DWITH_HASH
SUBDIRCFLAGS	+= -DHASHSTATS
SUBDIRS		+= hashmap
ZIPLIBS		+= hashmap/libhashmap.a
LIBS		+= -lcrypto $(PTHREADLIBS)
ifeq ($(WITH_HASHALIGN),1)
CFLAGS		+= -DWITH_HASHALIGN
endif
endif

ifeq ($(WITH_RANGEMAP),1)
ZIPCFLAGS	+= -DTEST_RANGEMAP
ZIPLIBS		+= libndz/libndz.a
endif

all:	$(PROGS)

whoami:
	@echo "SYSTEM is $(SYSTEM)"
ifeq ($(SYSTEM),FreeBSD)
	@echo "FBSDREL is $(FBSDREL)"
	@echo "FBSDMAJ is $(FBSDMAJ)"
endif

include $(TESTBED_SRCDIR)/GNUmakerules

imagezip: $(SUBDIRS) imagezip.o sliceinfo.o disksize.o checksum.o version.o $(ZIPLIBS)
	$(CC) $(CFLAGS) imagezip.o sliceinfo.o disksize.o checksum.o version.o $(ZIPLIBS) $(LIBS) -o imagezip

imagezip.o:	imagezip.c
	$(CC) -c $(ZIPCFLAGS) -o imagezip.o $<

imageunzip: $(UNZIPDIRS) imageunzip.o disksize.o checksum.o crc.o version.o
	$(CC) $(CFLAGS) imageunzip.o disksize.o checksum.o crc.o version.o $(UNZIPLIBS) -o imageunzip

imageunzip.o:	imageunzip.c
	$(CC) -c $(UNZIPCFLAGS) -o imageunzip.o $<

imagedump: imagedump.o checksum.o version.o
	$(CC) $(CFLAGS) imagedump.o checksum.o version.o $(LIBS) -o imagedump

imagehash: imagehash.o version.o
	$(CC) $(CFLAGS) imagehash.o version.o $(HASHLIBS) -o imagehash

imagehash.o:	imagehash.c
	$(CC) -c $(HASHCFLAGS) -o imagehash.o $<

imagedelta: imagedelta.o version.o $(NDZLIBS)
	$(CC) $(CFLAGS) imagedelta.o version.o $(NDZLIBS) -o imagedelta

imagedelta.o:	imagedelta.c
	$(CC) -c $(CFLAGS) -o imagedelta.o $<

imageundelta: imageundelta.o version.o $(NDZLIBS)
	$(CC) $(CFLAGS) imageundelta.o version.o $(NDZLIBS) -o imageundelta

imageundelta.o:	imageundelta.c
	$(CC) -c $(CFLAGS) -o imageundelta.o $<

imagerezip: imagerezip.o version.o $(NDZLIBS)
	$(CC) $(CFLAGS) imagerezip.o version.o $(NDZLIBS) -o imagerezip

imagerezip.o:	imagerezip.c
	$(CC) -c $(CFLAGS) -o imagerezip.o $<

sizetest: disksize.c
	$(CC) -DTEST $< -o sizetest

$(SUBDIRS):
	@$(MAKE) SUBDIRCFLAGS="$(SUBDIRCFLAGS)" -C $@ all

# XXX target for other software to build MBR/GPT libraries
partlibs:
ifeq ($(WITH_MBR),1)
	@$(MAKE) SUBDIRCFLAGS="$(SUBDIRCFLAGS)" -C mbr all
endif
ifeq ($(WITH_GPT),1)
	@$(MAKE) SUBDIRCFLAGS="$(SUBDIRCFLAGS)" -C gpt all
endif

imagezip.o: sliceinfo.h imagehdr.h global.h range.h hashmap/hashmap.h
imageunzip.o: imagehdr.h
imagehash.o: imagehdr.h imagehash.h
imagedelta.o: imagehdr.h imagehash.h libndz/libndz.h
imageundelta.o: imagehdr.h imagehash.h libndz/libndz.h
imagerezip.o: imagehdr.h imagehash.h libndz/libndz.h

version.c: imagezip.c imageunzip.c imagedump.c imagedelta.c imageundelta.c imagerezip.c
	echo >$@ "char build_info[] = \"Built `date +%d-%b-%Y` by `id -nu`@`hostname | sed 's/\..*//'`:`pwd`\";"

install: $(addprefix $(INSTALL_BINDIR)/, $(PROGS))

boss-install: install
control: all
control-install: control
subboss: all
subboss-install: subboss

client: all
client-install: client
	$(INSTALL) -m 755 -o root -d $(DESTDIR)/usr/local/bin
	$(INSTALL_PROGRAM) -s imagezip$(EXE) $(DESTDIR)/usr/local/bin/imagezip$(EXE)
	$(INSTALL_PROGRAM) -s imageunzip$(EXE) $(DESTDIR)/usr/local/bin/imageunzip$(EXE)
	$(INSTALL_PROGRAM) -s imagedump$(EXE) $(DESTDIR)/usr/local/bin/imagedump$(EXE)

clean: subdir-clean
	rm -f *.o imagezip imageunzip imagedump imagehash version.c
	rm -f imagezip.tar imagezip.tar.gz

subdir-clean:
	@list='$(SUBDIRS)'; for dir in $$list; do \
		$(MAKE) -C $$dir clean; \
	done;

distclean: subdir-distclean

subdir-distclean:
	@list='$(SUBDIRS)'; for dir in $$list; do \
		$(MAKE) -C $$dir distclean; \
	done;

imagezip.tar.gz: imagezip.tar
	gzip -c imagezip.tar > imagezip.tar.gz

imagezip.tar: Makefile.sa Makefile-linux.sa
	rm -rf imagezip-dist; mkdir imagezip-dist
	(cd $(SRCDIR); tar cf - Makefile.sa Makefile-linux.sa $(DISTFILES)) | \
		(cd imagezip-dist; tar xf -)
	mv imagezip-dist/Makefile.sa imagezip-dist/Makefile
	mv imagezip-dist/Makefile-linux.sa imagezip-dist/Makefile-linux
	(cd imagezip-dist; \
		$(EXPANDCOPYRIGHT) Makefile Makefile-linux $(DISTFILES))
	tar cf imagezip.tar imagezip-dist
	rm -rf imagezip-dist

.PHONY: $(SUBDIRS)
