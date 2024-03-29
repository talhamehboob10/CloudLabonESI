#
# Copyright (c) 2000-2006 University of Utah and the Flux Group.
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
SRCDIR		= ../../../www/tutorial
TESTBED_SRCDIR	= ../../..
OBJDIR		= ../..
SUBDIR		= www/tutorial

all: $(SRCDIR)/loghole.html

# We depend on the loghole.1 man page.  It is formated into text and then
# html, and added to the end of the loghole web page.
# 
# We also leave the checked-in loghole.html file, in order to avoid making a
# hard dependency on having man2html installed.  There will be a warning, but
# not an error, if this fails.  The original loghole.html will not be wiped out.
$(SRCDIR)/loghole.html: man1/loghole.1 $(SRCDIR)/loghole.html.head
	-( man -M . 1 loghole > loghole-man.txt && \
	   man2html -bare < loghole-man.txt > loghole-man.html && \
	   cat $(SRCDIR)/loghole.html.head loghole-man.html > loghole.html.new && \
	   mv loghole.html.new $(SRCDIR)/loghole.html )

# Gotta have a man1 directory for man to search for .1 files.
man1:
	mkdir man1
# Symlink the .1 source files into it for man to find.
# Add another layer of ../'s because it's a level lower in the tree.
# Don't error out if the symlink is already there.
man1/loghole.1: man1
	- ln -s ../$(TESTBED_SRCDIR)/utils/loghole.1 man1/loghole.1

clean:
	rm -rf man1 loghole-man.txt loghole-man.html loghole.html.new
