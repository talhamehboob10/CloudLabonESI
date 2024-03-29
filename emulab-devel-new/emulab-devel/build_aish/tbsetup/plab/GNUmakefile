#
# Copyright (c) 2000-2004, 2006 University of Utah and the Flux Group.
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

SRCDIR		= ../../../tbsetup/plab
TESTBED_SRCDIR	= ../../..
OBJDIR		= ../..
SUBDIR		= tbsetup/plab
UNIFIED         = 0

include $(OBJDIR)/Makeconf

SUBDIRS		= libdslice etc

SBIN_STUFF	= plabslice plabnode plabrenewd plabmetrics plabstats \
		  plabmonitord plablinkdata plabdist plabhttpd plabdiscover \
		  plabrenewonce plabnodehistclean plabnodehistmetrics \
		  plabfed

LIB_STUFF       = libplab.py mod_dslice.py mod_PLC.py mod_PLCNM.py \
		  mod_PLC4.py sshhttp.py \
		  plabmon_badpool.pm plabmon_goodpool.pm libplabmon.pm \
		  aspects.py timer_advisories.py \
		  libplabnodehist.pm

LIBEXEC_STUFF	= webplabstats

# These scripts installed setuid, with sudo. 
SETUID_BIN_SCRIPTS   = 
SETUID_SBIN_SCRIPTS  = plabslice plabnode plabrenewd
SETUID_LIBX_SCRIPTS  =

#
# Force dependencies on the scripts so that they will be rerun through
# configure if the .in file is changed.
# 
all:	$(SBIN_STUFF) $(LIB_STUFF) $(LIBEXEC_STUFF) $(SUBDIRS)

include $(TESTBED_SRCDIR)/GNUmakerules

.PHONY:	libdslice etc
libdslice:
	@$(MAKE) -C libdslice all

etc:
	@$(MAKE) -C etc all

install: all script-install subdir-install

#
# Automate this part at some point.
# 
subdir-install:
	@$(MAKE) -C libdslice install
	@$(MAKE) -C etc install

script-install:	 $(addprefix $(INSTALL_SBINDIR)/, $(SBIN_STUFF)) \
	 $(addprefix $(INSTALL_LIBEXECDIR)/, $(LIBEXEC_STUFF)) \
	 $(addprefix $(INSTALL_LIBDIR)/, $(LIB_STUFF))

post-install: 
	@$(MAKE) -C etc post-install
	chmod 775 $(INSTALL_SBINDIR)
	chmod 775 $(INSTALL_LIBDIR)
	chown root $(INSTALL_SBINDIR)/plabslice
	chmod u+s $(INSTALL_SBINDIR)/plabslice
	chown root $(INSTALL_SBINDIR)/plabnode
	chmod u+s $(INSTALL_SBINDIR)/plabnode
	chown root $(INSTALL_SBINDIR)/plabrenewd
	chmod u+s $(INSTALL_SBINDIR)/plabrenewd

clean:	subdir-clean

subdir-clean:
	@$(MAKE) -C libdslice clean
	@$(MAKE) -C etc clean

distclean:	subdir-distclean

subdir-distclean:
	@$(MAKE) -C libdslice distclean
	@$(MAKE) -C etc distclean
