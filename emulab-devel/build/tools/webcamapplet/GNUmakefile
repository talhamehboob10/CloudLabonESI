#
# Copyright (c) 2005 University of Utah and the Flux Group.
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

SRCDIR		= ../../../tools/webcamapplet
TESTBED_SRCDIR	= ../../..
OBJDIR		= ../..
SUBDIR		= tools/webcamapplet

include $(OBJDIR)/Makeconf

ifeq ($(JAVAC),)
JARS =
else
JARS = $(TESTBED_SRCDIR)/www/WebCamApplet.jar
endif

all:
jar: $(JARS)

include $(TESTBED_SRCDIR)/GNUmakerules

WebCamApplet.class: $(SRCDIR)/WebCamApplet.java
	$(JAVAC) -deprecation -d . $^

$(TESTBED_SRCDIR)/www/WebCamApplet.jar: WebCamApplet.class
	echo '$(filter-out WebCamApplet.class, $(shell echo *.class))'
	$(JAR) cvf $@ $^ $(patsubst %,'%',$(filter-out WebCamApplet.class, $(shell echo *.class)))

install:

clean:
	/bin/rm -f *.class *.jar

$(INSTALL_WWWDIR)/%: %
	@echo "Installing $<"
	-mkdir -p $(patsubst %/,%,$(dir $@))
	$(INSTALL_DATA) $(subst $$,\$$,$<) $(subst $$,\$$,$@) 
