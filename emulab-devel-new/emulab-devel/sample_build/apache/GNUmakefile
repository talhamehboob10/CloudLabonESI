#
# Copyright (c) 2002-2017, 2020 University of Utah and the Flux Group.
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
# For installation only.
#
SRCDIR		= ../../apache
TESTBED_SRCDIR	= ../..
OBJDIR		= ..
SUBDIR		= apache
PGENISUPPORT    = 1

SYSTEM	       := $(shell uname -s)
ifeq ($(SYSTEM),FreeBSD)
FBSDREL	:= $(shell uname -r | sed -e 's/\([^-][^-]*\)-.*/\1/')
FBSDMAJ := $(basename $(FBSDREL))
ifeq ($(FBSDMAJ),7)
SCRIPT_HACK	= 1
endif
endif

include $(OBJDIR)/Makeconf

OPS_FILES       = httpd.conf-ops php.ini
CONFIG_FILES	= httpd.conf $(OPS_FILES)
ifeq ($(PGENISUPPORT),1)
CONFIG_GENI     = httpd-geni.conf
CONFIG_FILES   += $(CONFIG_GENI)
endif

ifeq ($(APACHE_VERSION),24)
# For VPATH.
MOSTLY_SRCDIRS = ${SRCDIR}/v24
SCRIPT_HACK     = 0
else
ifeq ($(APACHE_VERSION),22)
# For VPATH.
MOSTLY_SRCDIRS = ${SRCDIR}/v2
SCRIPT_HACK     = 0
else
MOSTLY_SRCDIRS = ${SRCDIR}/v1
endif
endif
INSTALL_PHP_CONFIG = /usr/local/etc

#
# Force dependencies to make sure configure regenerates if the .in file
# is changed.
# 
all: $(CONFIG_FILES)

control-build: $(OPS_FILES)

include $(TESTBED_SRCDIR)/GNUmakerules

#
# Override version from GNUmakerules since the source is kept in a
# different place, and the config script is a pain to work with.
# Maybe we can just make this the default in GNUmakerules. 
#
%: %.in $(OBJDIR)/config.status
	@echo "Regenerating $@ from $(subst $(TESTBED_SRCDIR)/,,$<)"
	cd $(OBJDIR) && CONFIG_FILES=$(SUBDIR)/$@:$(subst $(TESTBED_SRCDIR)/,,$<) ./config.status

# Like the INSTALL_ETCDIR target
$(INSTALL_APACHE_CONFIG)/%: %
	@echo "Installing $<"
	-mkdir -p $(INSTALL_APACHE_CONFIG)
	$(INSTALL_DATA) $< $@


#
# XXX hack, hack: need to fix the path to the auth_mysql_module
# This could (should?) be done with configure, but apache port might
# not be installed when we configure our software.
#
# XXX ugh, do the same thing to detect php5...
#
# Note that this is not needed for apache22.
#
httpd.conf.fixed: httpd.conf
	-@cp httpd.conf httpd.conf.fixed
	@if [ -x /usr/local/libexec/apache/mod_auth_mysql.so ]; then \
            sed -i "" -e '/^LoadModule auth_mysql/s/libauth/mod_auth/' httpd.conf.fixed; \
	    echo "Updated httpd.conf for auth_mysql"; \
	fi
	@if [ -x /usr/local/libexec/apache/libphp5.so ]; then \
            sed -i "" -e 's/php4/php5/g' httpd.conf.fixed; \
	    echo "Updated httpd.conf for php5"; \
	fi

httpd.conf-ops.fixed: httpd.conf-ops
	-@cp httpd.conf-ops httpd.conf-ops.fixed
	@if [ true -o -x /usr/local/libexec/apache/libphp5.so ]; then \
            sed -i "" -e 's/php4/php5/g' httpd.conf-ops.fixed; \
	    echo "Updated httpd.conf-ops for php5"; \
	fi

install-dirs:
	-mkdir -p $(INSTALL_TOPDIR)/www

#
# Well, this is awkward.  Make sure we don't try to install anything from
# a dev tree both because it doesn't make any sense and because it would
# clobber the "real" version.
#
ifeq ($(TBROOT),/usr/testbed)
#
# XXX another woeful hack.  There appears to be a well-documented problem
# with Apache and PHP4, where loading PHP with certain extensions will cause
# Apache to crash immediately.  However, if you start it without PHP and then
# use apachectl to restart it *with* PHP, all is well.  Go figure...
# We install this script which accomodates that...ahem, "behavior."
# Since we have only seen this on FBSD7, we only do it there.
#
# Note that we install apache-emulab as apache.sh to be consistant with
# with what {boss,ops}-install expect.
#
install-scripts: apache-emulab
ifeq ($(SCRIPT_HACK),1)
	@if [ -f /usr/local/etc/rc.d/apache -a ! -f /usr/local/etc/rc.d/.apache.real ]; then \
	    mv /usr/local/etc/rc.d/apache /usr/local/etc/rc.d/.apache.real; \
	fi
	$(INSTALL) -m 755 $(SRCDIR)/apache-emulab /usr/local/etc/rc.d/apache.sh
endif

ifeq ($(APACHE_VERSION),1.3)
install: install-dirs install-scripts httpd.conf.fixed
	$(INSTALL_DATA) httpd.conf.fixed $(INSTALL_APACHE_CONFIG)/httpd.conf

control-install: install-dirs install-scripts httpd.conf-ops.fixed
	$(INSTALL_DATA) httpd.conf-ops.fixed $(INSTALL_APACHE_CONFIG)/httpd.conf
else
install: install-dirs install-scripts httpd.conf pgeni-install
	$(INSTALL_DATA) httpd.conf $(INSTALL_APACHE_CONFIG)/httpd.conf

install-utah-nets:
	$(INSTALL_DATA) $(SRCDIR)/utah-nets.conf \
		$(INSTALL_APACHE_CONFIG)/utah-nets.conf

control-install: install-dirs install-scripts httpd.conf-ops
	$(INSTALL_DATA) httpd.conf-ops $(INSTALL_APACHE_CONFIG)/httpd.conf

pgeni-install: $(CONFIG_GENI)
ifeq ($(PGENISUPPORT),1)
	$(INSTALL_DATA) httpd-geni.conf $(INSTALL_APACHE_CONFIG)/httpd-geni.conf
endif

utah: httpd.conf.utah httpd.conf-ops.utah
endif

install-php-ini: php.ini
	$(INSTALL_DATA) php.ini $(INSTALL_PHP_CONFIG)/php.ini
else
install-scripts install control-install:
	@echo "Cannot install Apache config in dev tree"
endif

clean:
	rm -f $(CONFIG_FILES) *.fixed php.ini
