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

SRCDIR		= ../../../www/garcia-telemetry
TESTBED_SRCDIR	= ../../..
OBJDIR		= ../..
SUBDIR		= www/garcia-telemetry

include $(OBJDIR)/Makeconf

ifeq ($(JAVAC),)
JARS =
else
JARS = ../garcia-telemetry.jar
endif

all: $(JARS)

include $(TESTBED_SRCDIR)/GNUmakerules

CLASSES_SRC = \
	Base64.java \
	GarciaTelemetry.java \
	UpdateThread.java

CLASSES = $(patsubst %.java,%.class,$(CLASSES_SRC))

MYCLASSPATH = \
	$(SRCDIR)/../thinlet.jar:$(SRCDIR)/../oncrpc.jar:$(SRCDIR)/../mtp.jar

$(CLASSES): $(CLASSES_SRC)
	env CLASSPATH=$(MYCLASSPATH) $(JAVAC) -d . $^

../garcia-telemetry.jar: $(CLASSES) main.xml
	cp -f $(filter $(SRCDIR)/%,$^) .
	$(JAR) cvf $@ $(patsubst $(SRCDIR)/%,%,$^) \
		'Base64$$OutputStream.class' 'Base64$$InputStream.class'
	rm -f $(patsubst $(SRCDIR)/%,%,$(filter $(SRCDIR)/%,$^))

clean:
	rm -f $(JARS) *.class
