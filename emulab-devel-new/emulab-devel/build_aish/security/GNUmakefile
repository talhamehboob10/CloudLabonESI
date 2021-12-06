#
# Copyright (c) 2000-2021 University of Utah and the Flux Group.
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

SRCDIR		= ../../security
TESTBED_SRCDIR	= ../..
OBJDIR		= ..
SUBDIR		= security

include $(OBJDIR)/Makeconf

BINS		= suexec runsuid
SBINS		= genlastlog lastlog_daemon runmedusa sshbanlist
OTHERS          = hosts.allow
CTRL_SBINS      = sshbanlist

# These scripts installed setuid, with sudo. 
SETUID_BIN_SCRIPTS   = 
SETUID_SBIN_SCRIPTS  =
SETUID_LIBX_PROGS    = suexec runsuid
SETUID_CTRL_LIBX_PROGS = runsuid

#
# Force dependencies on the scripts so that they will be rerun through
# configure if the .in file is changed.
# 
all:	$(BINS) $(SBINS) $(OTHERS)

include $(TESTBED_SRCDIR)/GNUmakerules

CFLAGS	+= -O2 -g

suexec:		suexec.c suexec.h
	$(CC) $(CFLAGS) \
		-DLOG_EXEC='"$(prefix)/log/suexec.log"' \
		-DDOC_ROOT='"$(prefix)/libexec/"' \
		-DSAFE_PATH='"$(prefix)/libexec:/usr/local/bin:/usr/bin:/bin"'\
		-o suexec $<

runsuid:	runsuid.c ${OBJDIR}/config.h
	$(CC) $(CFLAGS) -I${OBJDIR} -o runsuid $<

genlastlog:	genlastlog.c
	$(CC) $(CFLAGS) -I/usr/local/include -I$(TESTBED_LIBSRCDIR)/libtb \
		-DTBDBNAME='"$(TBDBNAME)"' \
		-DUSERSVAR='"$(prefix)/usersvar"' \
		-DOURDOMAIN='"$(OURDOMAIN)"' \
                -DUSERNODE='"$(USERNODE)"' \
		-DLOG_TESTBED=$(LOG_TESTBED) \
		-o genlastlog $< ${TESTBED_LIBOBJDIR}/libtb/libtb.a \
		-L/usr/local/lib/mysql -lmysqlclient -lz

install: $(addprefix $(INSTALL_LIBEXECDIR)/, $(BINS)) \
	$(addprefix $(INSTALL_SBINDIR)/, $(SBINS)) \
	$(addprefix $(INSTALL_DIR)/opsdir/libexec/, $(SETUID_CTRL_LIBX_PROGS)) \
	$(addprefix $(INSTALL_DIR)/opsdir/sbin/, $(CTRL_SBINS))

install-hosts-allow: hosts.allow
	sudo $(INSTALL_DATA) hosts.allow /etc/hosts.allow
	sudo scp hosts.allow $(USERNODE):/etc

post-install:
	@echo "post-install no longer required"

control-install: \
	$(addprefix $(INSTALL_LIBEXECDIR)/, $(SETUID_CTRL_LIBX_PROGS)) \
	$(addprefix $(INSTALL_SBINDIR)/, $(CTRL_SBINS))

$(INSTALL_DIR)/opsdir/libexec/runsuid: runsuid
	echo "Installing (setuid) $<"
	-mkdir -p $(INSTALL_DIR)/opsdir/libexec
	$(SUDO) $(INSTALL) -o root -m 4755 $< $@

$(INSTALL_DIR)/opsdir/sbin/%: %
	@echo "Installing $<"
	-mkdir -p $(INSTALL_DIR)/opsdir/sbin
	$(INSTALL) $< $@

clean:
	rm -f *.o genlastlog suexec runsuid core
