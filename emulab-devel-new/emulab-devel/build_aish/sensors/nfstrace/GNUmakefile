#
# Copyright (c) 2005, 2006, 2007, 2010 University of Utah and the Flux Group.
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
# This is the Emulab specific makefile.
#

SRCDIR          = ../../../sensors/nfstrace
TESTBED_SRCDIR  = ../../..
OBJDIR          = ../..
SUBDIR          = sensors/nfstrace

NFSTRACESUPPORT = 0

include $(OBJDIR)/Makeconf

all: nfstrace.proxy nfsdump2db nfsdump nfstrace.init

include $(TESTBED_SRCDIR)/GNUmakerules

#
# Install to the ops directory.
#
PREFIX=$(INSTALL_DIR)/opsdir
INSTALL_ETC=$(PREFIX)/etc
INSTALL_INITD=$(PREFIX)/etc/rc.d
INSTALL_SBIN=$(PREFIX)/sbin
INSTALL_MAN=$(PREFIX)/man

PW=/usr/sbin/pw
NFSTRACE_HOME=/var/nfstrace
NFSTRACE_DBDIR=/var/db/nfstrace

nfsdump:
	cd nfsdump2 && $(MAKE)
	cp nfsdump2/nfsdump2/nfsdump nfsdump

client client-install control-install:

$(NFSTRACE_HOME):
	sudo mkdir -m 0750 $(NFSTRACE_HOME)

add-nfstrace-user: $(NFSTRACE_HOME)
	@if ! id nfstrace > /dev/null 2>&1; then \
		sudo $(PW) useradd nfstrace -d $(NFSTRACE_HOME) \
			-s /sbin/nologin -u 50,200 \
			-c "NFS Tracing Daemon"; \
	fi
	@if ! id -Gn mysql | grep nfstrace > /dev/null 2>&1; then \
		sudo $(PW) usermod -n mysql -G "`id -Gn mysql` nfstrace"; \
	fi
	sudo chown nfstrace $(NFSTRACE_HOME)
	sudo chgrp wheel $(NFSTRACE_HOME)
	sudo chgrp nfstrace /dev/bpf0
	sudo chmod g+r /dev/bpf0

$(NFSTRACE_DBDIR):
	sudo mkdir -m 0750 -p $@
	sudo chown nfstrace $@
	sudo chgrp nfstrace $@

$(NFSTRACE_HOME)/dbpass:
	head -c 32 /dev/urandom | md5 -q | head -c 8 > $@
	sudo chown nfstrace $@
	sudo chgrp wheel $@
	sudo chmod o-r $@
	@if test ! -s $@; then \
		echo "error: generated empty password..."; \
		rm $@; \
		exit 1; \
	fi

$(NFSTRACE_HOME)/.my.cnf: $(NFSTRACE_HOME)/dbpass
	echo "[client]" > $@
	echo "user=nfstrace" >> $@
	echo "password=`cat $(NFSTRACE_HOME)/dbpass`" >> $@
	echo "[mysqldump]" >> $@
	echo "user=nfstrace" >> $@
	echo "password=`cat $(NFSTRACE_HOME)/dbpass`" >> $@
	sudo chown nfstrace $@
	sudo chgrp wheel $@
	sudo chmod o-r $@

# XXX Needs to be updated to properly create the DB and user.
create-db: $(NFSTRACE_HOME)/.my.cnf $(NFSTRACE_DBDIR)
	@if ! id mysql > /dev/null 2>&1; then \
		:; \
	elif sudo -u nfstrace -H mysqldump -d nfsdb > nfsdb-dump.sql; then \
		perl $(TESTBED_SRCDIR)/utils/schemadiff nfsdb-dump.sql \
			$(SRCDIR)/nfsdb-create.sql > nfsdb.diff; \
		if test -s nfsdb.diff; then \
			echo "error: nfsdb is out of sync"; \
			cat nfsdb.diff; \
			exit 1; \
		fi \
	else \
		echo "create database nfsdb" | sudo -u root mysql; \
		sudo -u nfstrace -H mysql nfsdb < $(SRCDIR)/nfsdb-create.sql; \
	fi

ifeq ($(NFSTRACESUPPORT),1)
fs-install: all add-nfstrace-user create-db
	-mkdir -p $(INSTALL_DIR)/sbin
	-mkdir -p $(INSTALL_DIR)/etc
	-mkdir -p $(INSTALL_DIR)/etc/rc.d
	$(INSTALL) -m 0755 nfsdump $(DESTDIR)$(INSTALL_SBINDIR)
	$(INSTALL) -m 0755 $(SRCDIR)/nfsdump2db $(DESTDIR)$(INSTALL_SBINDIR)
	$(INSTALL) -m 0755 $(SRCDIR)/nfstrace.proxy $(DESTDIR)$(INSTALL_SBINDIR)
	$(INSTALL) -m 0755 nfstrace.init $(INSTALL_DIR)/etc/rc.d/nfstrace
	-mkdir -p $(INSTALL_DIR)/man/man8
	$(INSTALL) -m 0644 $(SRCDIR)/nfstrace.proxy.8 \
		$(INSTALL_DIR)/man/man8/nfstrace.proxy.8
	$(INSTALL) -m 0644 $(SRCDIR)/nfsdump2db.8 \
		$(INSTALL_DIR)/man/man8/nfsdump2db.8
	-mkdir -p $(INSTALL_DIR)/man/man7
	$(INSTALL) -m 0644 $(SRCDIR)/nfstrace.7 \
		$(INSTALL_DIR)/man/man7/nfstrace.7

install: all
	$(INSTALL) -m 0755 nfsdump $(DESTDIR)$(INSTALL_SBIN)
	$(INSTALL) -m 0755 $(SRCDIR)/nfsdump2db $(DESTDIR)$(INSTALL_SBIN)
	$(INSTALL) -m 0755 $(SRCDIR)/nfstrace.proxy $(DESTDIR)$(INSTALL_SBIN)
	-mkdir -p $(DESTDIR)$(INSTALL_ETC)/rc.d
	$(INSTALL) -m 0755 nfstrace.init $(DESTDIR)$(INSTALL_ETC)/rc.d/nfstrace
	-mkdir -p $(INSTALL_DIR)/opsdir/man/man8
	$(INSTALL) -m 0644 $(SRCDIR)/nfstrace.proxy.8 \
		$(INSTALL_DIR)/opsdir/man/man8/nfstrace.proxy.8
	$(INSTALL) -m 0644 $(SRCDIR)/nfsdump2db.8 \
		$(INSTALL_DIR)/opsdir/man/man8/nfsdump2db.8
	-mkdir -p $(INSTALL_DIR)/opsdir/man/man7
	$(INSTALL) -m 0644 $(SRCDIR)/nfstrace.7 \
		$(INSTALL_DIR)/opsdir/man/man7/nfstrace.7
else
fs-install install:
endif

clean:
	cd nfsdump2 && $(MAKE) clean
	rm -f *.o core nfsdump nfstrace.init
