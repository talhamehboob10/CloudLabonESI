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
SRCDIR		= ../../www
TESTBED_SRCDIR	= ../..
OBJDIR		= ..
SUBDIR		= www

#
# A hack for only installing some things if installing on the main site
#
MAINSITE        = emulab.net
OURDOMAIN       = cloudlab.umass.edu
CVSSUPPORT      = 0
CHATSUPPORT     = 0
PGENISUPPORT    = 1

# Filter program
HTMLINSTALL     = $(INSTALL_SBINDIR)/htmlinstall  

include $(OBJDIR)/Makeconf

SUBDIRS = tutorial

#
# Force dependencies to make sure configure regenerates if the .in file
# is changed.
# 
all: defs.php3 dbdefs.php3 websearch htmlinstall xmlrpc.php3 \
	xmlrpcpipe.php3 blob/read.php3 all-subdirs

include $(TESTBED_SRCDIR)/GNUmakerules

#
# Generate a list of all the files we want to install from the current
# directory and the source directory. 
#
FILES	= $(wildcard *.css *.jpg *.gif *.png *.html *.php3 *.php *.ico *.jar)
FILES  += $(wildcard $(SRCDIR)/*.css)
FILES  += $(wildcard $(SRCDIR)/*.jpg)
FILES  += $(wildcard $(SRCDIR)/*.png)
FILES  += $(wildcard $(SRCDIR)/*.gif)
FILES  += $(wildcard $(SRCDIR)/*.html)
FILES  += $(wildcard $(SRCDIR)/*.php3)
FILES  += $(wildcard $(SRCDIR)/*.php)
FILES  += $(wildcard $(SRCDIR)/*.ico)
FILES  += $(wildcard $(SRCDIR)/*.class)
FILES  += $(wildcard $(SRCDIR)/*.jar)
FILES  += $(wildcard $(SRCDIR)/*.js)
FILES  += $(wildcard $(SRCDIR)/*.htc)
FILES  += $(SRCDIR)/.htaccess $(SRCDIR)/error.shtml \
	  $(SRCDIR)/ssh-mime.pl $(SRCDIR)/rdp-mime.pl \
	  $(SRCDIR)/emulab.app \
	  $(SRCDIR)/ssh-mime-winxp.pl $(SRCDIR)/rdp-mime-winxp.pl \
	  $(SRCDIR)/ssh-mime-winxp.c $(SRCDIR)/rdp-mime-winxp.c \
	  $(SRCDIR)/ssh-mime-winxp.exe $(SRCDIR)/rdp-mime-winxp.exe \
	  $(SRCDIR)/emulab-mime-winxp.zip $(SRCDIR)/emulab-mime-winxp.reg \
	  $(SRCDIR)/emusearch.xml
ifeq ($(TBROOT),/usr/testbed)
FILES  += robots.txt
endif 

AUTOICONS  = $(wildcard $(SRCDIR)/autostatus-icons/*.gif)
AUTOICONS += $(wildcard $(SRCDIR)/autostatus-icons/*.png)

FLOORMAPFILES  = $(wildcard $(SRCDIR)/floormap/*.jpg)
FLOORMAPFILES += $(wildcard $(SRCDIR)/floormap/*.gif)

WIRELESSSTATSFILES = $(wildcard $(SRCDIR)/wireless-stats/*.php3)
WIRELESSSTATSFILES += $(wildcard $(SRCDIR)/wireless-stats/*.jar)

PIXFILES  = $(wildcard $(SRCDIR)/pix/*.jpg)
PIXFILES += $(wildcard $(SRCDIR)/pix/*.gif)

DOCFILES  = $(wildcard $(SRCDIR)/doc/*.html)
DOCFILES += $(wildcard $(SRCDIR)/doc/*.jpg)
DOCFILES += $(wildcard $(SRCDIR)/doc/*.gif)
DOCFILES += $(wildcard $(SRCDIR)/doc/*.php3)
DOCFILES += $(wildcard $(SRCDIR)/doc/*.php)
DOCFILES += $(wildcard $(SRCDIR)/doc/*.ps)
DOCFILES += $(wildcard $(SRCDIR)/doc/*.pdf)
DOCFILES += $(wildcard $(SRCDIR)/doc/*.svg)

TUTFILES  = $(wildcard $(SRCDIR)/tutorial/*.html)
TUTFILES += $(wildcard $(SRCDIR)/tutorial/*.jpg)
TUTFILES += $(wildcard $(SRCDIR)/tutorial/*.gif)
TUTFILES += $(wildcard $(SRCDIR)/tutorial/*.png)
TUTFILES += $(wildcard $(SRCDIR)/tutorial/*.php3)
TUTFILES += $(wildcard $(SRCDIR)/tutorial/*.php)
TUTFILES += $(wildcard $(SRCDIR)/tutorial/*.ns)
TUTFILES += $(wildcard $(SRCDIR)/tutorial/*.txt)
TUTFILES += $(SRCDIR)/tutorial/tb_compat.tcl

BUIFILES  = $(wildcard $(SRCDIR)/buildui/*.html)
BUIFILES += $(wildcard $(SRCDIR)/buildui/*.jpg)
BUIFILES += $(wildcard $(SRCDIR)/buildui/*.gif)
BUIFILES += $(wildcard $(SRCDIR)/buildui/*.php3)
BUIFILES += $(wildcard $(SRCDIR)/buildui/*.php)
BUIFILES += $(wildcard $(SRCDIR)/buildui/*.class)

NLFILES  = $(wildcard $(SRCDIR)/netlab/*.html)
NLFILES += $(wildcard $(SRCDIR)/netlab/*.php3)
NLFILES += $(wildcard $(SRCDIR)/netlab/*.png)
NLFILES += $(wildcard $(SRCDIR)/netlab/*.gif)
NLFILES += $(wildcard $(SRCDIR)/netlab/*.txt)

PGENIFILES = 
ifeq ($(PGENISUPPORT),1)
    PGENIFILES += $(wildcard $(SRCDIR)/protogeni/*.php3)
    PGENIFILES += $(wildcard $(SRCDIR)/protogeni/*.php)
    PGENIFILES += $(wildcard $(SRCDIR)/protogeni/*.xml)
endif

HYFILES  = $(wildcard $(SRCDIR)/hyperviewer/*.php3)
HYFILES += $(wildcard $(SRCDIR)/hyperviewer/*.html)
HYFILES += $(wildcard $(SRCDIR)/hyperviewer/*.jpg)
HYFILES += $(wildcard $(SRCDIR)/hyperviewer/*.gif)

TTFILES  = $(wildcard $(SRCDIR)/timetree/*.png)
TTFILES += $(wildcard $(SRCDIR)/timetree/*.js)
TTFILES += $(wildcard $(SRCDIR)/timetree/*.css)

UMFILES  = $(wildcard $(SRCDIR)/usermap/*.php)
UMFILES += $(wildcard $(SRCDIR)/usermap/*.png)
UMFILES += $(wildcard $(SRCDIR)/usermap/*.js)

JSFILES += $(wildcard $(SRCDIR)/js/*.js)

BLOBFILES += $(wildcard blob/*.php3)

APTUIFILES  = $(wildcard $(SRCDIR)/aptui/*.html)
APTUIFILES += $(wildcard $(SRCDIR)/aptui/*.php)
APTUIFILES += $(wildcard $(SRCDIR)/aptui/*.ajax)
APTUIFILES += $(wildcard $(SRCDIR)/aptui/*.png)
APTUIFILES += $(wildcard $(SRCDIR)/aptui/*.ico)
APTUIFILES += $(wildcard $(SRCDIR)/aptui/*.gif)
APTUIFILES += $(wildcard $(SRCDIR)/aptui/.htaccess)
APTJSFILES  = $(wildcard $(SRCDIR)/aptui/js/*.js)
APTLIBFILES = $(wildcard $(SRCDIR)/aptui/js/lib/*.js)
APTJQRFILES = $(wildcard $(SRCDIR)/aptui/js/lib/jQRangeSlider/*.js)
APTSORTFILES = $(wildcard $(SRCDIR)/aptui/js/lib/tablesorter/*.js)
APTSORTFILES += $(wildcard $(SRCDIR)/aptui/js/lib/tablesorter/widgets/*.js)
APTSORTFILES += $(wildcard $(SRCDIR)/aptui/js/lib/tablesorter/parsers/*.js)
APTPAKOFILES = $(wildcard $(SRCDIR)/aptui/js/lib/pako/*.js)
APTTEMPLATES = $(wildcard $(SRCDIR)/aptui/template/*.html)
APTTEMPLATES += $(wildcard $(SRCDIR)/aptui/template/*.md)
APTCSSFILES = $(wildcard $(SRCDIR)/aptui/css/*.css)
APTFONTS = $(wildcard $(SRCDIR)/aptui/fonts/*)
APTIMAGES = $(wildcard $(SRCDIR)/aptui/images/*)
JSTREE = $(wildcard $(SRCDIR)/aptui/jstree/*)
AFFILIATIONS = $(wildcard $(SRCDIR)/aptui/affiliations/*)

APTNEWJSFILES   = $(wildcard $(SRCDIR)/aptui/js/new/*.js)
APTNEWTEMPLATES = $(wildcard $(SRCDIR)/aptui/template/new/*.html)

# need to make it *.gz; with simply "*", 
# we end up sucking over "CVS"
DOWNLOADFILES = $(wildcard $(SRCDIR)/downloads/*.gz)
DOWNLOADFILES += $(wildcard $(SRCDIR)/downloads/*.zip)
DOWNLOADFILES += $(wildcard $(SRCDIR)/downloads/*.exe)

#
# This stuff only gets installed on the main site
#
ifeq ($(CVSSUPPORT),1)
	CVSWEBFILES  = $(wildcard $(SRCDIR)/cvsweb/*.php3)
	CVSWEBFILES += $(wildcard $(SRCDIR)/cvsweb/*.php)
	CVSWEBFILES += $(wildcard $(SRCDIR)/cvsweb/*.conf)
	CVSWEBFILES += $(wildcard $(SRCDIR)/cvsweb/*.gif)
	CVSWEBCGI    = $(wildcard $(SRCDIR)/cvsweb/*.cgi)

	INSTALL_CVSWEBCGI = $(INSTALL_PROGRAM) $(CVSWEBCGI) $(INSTALL_WWWDIR)/cvsweb
endif

ifeq ($(CVSSUPPORT),1) 
	OPSCVSWEBFILES  = $(wildcard $(SRCDIR)/cvsweb/*.gif)
	OPSCVSWEBCONF   = $(wildcard $(SRCDIR)/cvsweb/cvsweb-ops.conf)
	OPSCVSWEBCGI    = $(wildcard $(SRCDIR)/cvsweb/*.cgi)

	INSTALL_OPSCVSWEBCGI = $(INSTALL_PROGRAM) $(OPSCVSWEBCGI) \
			$(INSTALL_DIR)/opsdir/www/cvsweb
	INSTALL_OPSCVSWEBCONF = $(INSTALL_DATA) $(OPSCVSWEBCONF) \
			$(INSTALL_DIR)/opsdir/www/cvsweb/cvsweb.conf
endif

ifeq ($(CHATSUPPORT),1) 
	INSTALL_OPSJABBER = $(INSTALL_DATA) $(SRCDIR)/jabber/jeti.php \
			$(INSTALL_DIR)/opsdir/www/jabber
endif

#
# Kill the directory part of the names. The vpath rule will do the rest.
#
ALLFILES  = $(notdir $(FILES))
ALLFLOORMAPS  = $(notdir $(FLOORMAPFILES))
ALLPIXES  = $(notdir $(PIXFILES))
ALLDOCS   = $(notdir $(DOCFILES))
ALLTUTS   = $(notdir $(TUTFILES))
ALLICONS  = $(notdir $(AUTOICONS))
ALLPGENI  = $(notdir $(PGENIFILES))
ALLDOWNLOADS = $(notdir $(DOWNLOADFILES))
ALLCVSWEB = $(notdir $(CVSWEBFILES))
ALLOPSCVSWEB = $(notdir $(OPSCVSWEBFILES))
ALLBUI    = $(notdir $(BUIFILES))
ALLNL     = $(notdir $(NLFILES))
ALLHY     = $(notdir $(HYFILES))
ALLTT     = $(notdir $(TTFILES))
ALLUM     = $(notdir $(UMFILES))
ALLJS     = $(notdir $(JSFILES))
ALLWISTATS = $(notdir $(WIRELESSSTATSFILES))
ALLBLOB   = $(notdir $(BLOBFILES))
ALLAPTUI  = $(notdir $(APTUIFILES))
ALLAPTJS  = $(notdir $(APTJSFILES))
ALLAPTLIB = $(notdir $(APTLIBFILES))
ALLAPTJQR = $(notdir $(APTJQRFILES))
ALLAPTPAKO = $(notdir $(APTPAKOFILES))
ALLAPTTEMPLATES = $(notdir $(APTTEMPLATES))
ALLAPTCSS = $(notdir $(APTCSSFILES))
ALLAPTFONTS = $(notdir $(APTFONTS))
ALLAPTIMAGES = $(notdir $(APTIMAGES))
ALLJSTREE = $(notdir $(JSTREE))
ALLAFFIL = $(notdir $(AFFILIATIONS))
ALLAPTSORT = $(subst $(SRCDIR)/aptui/js/lib/,,$(APTSORTFILES))

ALLAPTNEWJS  = $(notdir $(APTNEWJSFILES))
ALLAPTNEWTEMPLATES = $(notdir $(APTNEWTEMPLATES))

INSTALLFILES = $(addprefix $(INSTALL_SBINDIR)/, htmlinstall) \
	$(addprefix $(INSTALL_WWWDIR)/, $(ALLFILES)) \
	$(addprefix $(INSTALL_WWWDIR)/floormap/, $(ALLFLOORMAPS)) \
	$(addprefix $(INSTALL_WWWDIR)/pix/, $(ALLPIXES)) \
	$(addprefix $(INSTALL_WWWDIR)/tutorial/, $(ALLTUTS)) \
	$(addprefix $(INSTALL_WWWDIR)/doc/, $(ALLDOCS)) \
	$(addprefix $(INSTALL_WWWDIR)/protogeni/, $(ALLPGENI)) \
	$(addprefix $(INSTALL_WWWDIR)/downloads/, $(ALLDOWNLOADS)) \
	$(addprefix $(INSTALL_WWWDIR)/buildui/, $(ALLBUI)) \
	$(addprefix $(INSTALL_WWWDIR)/netlab/, $(ALLNL)) \
	$(addprefix $(INSTALL_WWWDIR)/hyperviewer/, $(ALLHY)) \
	$(addprefix $(INSTALL_WWWDIR)/timetree/, $(ALLTT)) \
	$(addprefix $(INSTALL_WWWDIR)/usermap/, $(ALLUM)) \
	$(addprefix $(INSTALL_WWWDIR)/js/, $(ALLJS)) \
	$(addprefix $(INSTALL_WWWDIR)/wireless-stats/, $(ALLWISTATS)) \
	$(addprefix $(INSTALL_WWWDIR)/autostatus-icons/, $(ALLICONS)) \
	$(addprefix $(INSTALL_WWWDIR)/blob/, $(ALLBLOB)) \
	$(addprefix $(INSTALL_LIBEXECDIR)/, websearch) \
	$(addprefix $(INSTALL_SBINDIR)/, htmlinstall) \
	$(addprefix $(INSTALL_WWWDIR)/cvsweb/, $(ALLCVSWEB)) \
	$(addprefix $(INSTALL_DIR)/opsdir/www/cvsweb/, $(ALLOPSCVSWEB)) \
	$(INSTALL_DIR)/opsdir/www/webssh/webssh.html \
	$(INSTALL_DIR)/opsdir/www/accept_cert.html \
	$(INSTALL_WWWDIR)/wikidocs/wiki/ignore.html \
	$(INSTALL_WWWDIR)/doc/LICENSE.txt

install: $(INSTALLFILES) apt-install
	-mkdir -p $(INSTALL_WWWDIR)/wikidocs/wiki
	cd $(INSTALL_WWWDIR) && \
		rm -f tbdb.html; \
		ln -s index.html tbdb.html; \
		rm -f icons; \
		ln -s /usr/local/www/icons icons;
ifeq ($(CHATSUPPORT),1) 
	-mkdir -p $(INSTALL_DIR)/opsdir/www/jabber
	$(INSTALL_OPSJABBER)
endif
	$(INSTALL_CVSWEBCGI)
	$(INSTALL_OPSCVSWEBCONF)
	$(INSTALL_OPSCVSWEBCGI)
	cd $(OBJDIR) && gmake install-setbuildinfo

apt-install: 	$(addprefix $(INSTALL_WWWDIR)/apt/, $(ALLAPTUI)) \
	$(addprefix $(INSTALL_WWWDIR)/apt/js/, $(ALLAPTJS)) \
	$(addprefix $(INSTALL_WWWDIR)/apt/js/lib/, $(ALLAPTLIB)) \
	$(addprefix $(INSTALL_WWWDIR)/apt/js/lib/jQRangeSlider/, $(ALLAPTJQR)) \
	$(addprefix $(INSTALL_WWWDIR)/apt/js/lib/pako/, $(ALLAPTPAKO)) \
	$(addprefix $(INSTALL_WWWDIR)/apt/js/lib/, $(ALLAPTSORT)) \
	$(addprefix $(INSTALL_WWWDIR)/apt/template/, $(ALLAPTTEMPLATES)) \
	$(addprefix $(INSTALL_WWWDIR)/apt/css/, $(ALLAPTCSS)) \
	$(addprefix $(INSTALL_WWWDIR)/apt/fonts/, $(ALLAPTFONTS)) \
	$(addprefix $(INSTALL_WWWDIR)/apt/images/, $(ALLAPTIMAGES)) \
	$(addprefix $(INSTALL_WWWDIR)/apt/jstree/, $(ALLJSTREE)) \
	$(addprefix $(INSTALL_WWWDIR)/apt/affiliations/, $(ALLAFFIL)) \
	$(addprefix $(INSTALL_WWWDIR)/apt/js/new/, $(ALLAPTNEWJS)) \
	$(addprefix $(INSTALL_WWWDIR)/apt/template/new/, $(ALLAPTNEWTEMPLATES))
	cd $(INSTALL_WWWDIR) && \
		rm -f portal; \
		ln -s apt portal;

post-install:

boss-install:	install

uninstall:
	rm -f $(INSTALLFILES)

force-install:	uninstall install

$(INSTALL_WWWDIR)/doc/LICENSE.txt: $(TESTBED_SRCDIR)/AGPL-COPYING
	@echo "Installing $<"
	-mkdir -p $(patsubst %/,%,$(dir $@))
	$(INSTALL_DATA) $(subst $$,\$$,$<) $(subst $$,\$$,$@)

$(INSTALL_WWWDIR)/%.html: %.html htmlinstall
	@echo "Installing $<"
	-mkdir -p $(patsubst %/,%,$(dir $@))
	$(HTMLINSTALL) $(subst $$,\$$,$<) $(subst $$,\$$,$@)

$(INSTALL_WWWDIR)/%: %
	@echo "Installing $<"
	-mkdir -p $(patsubst %/,%,$(dir $@))
	$(INSTALL_DATA) $(subst $$,\$$,$<) $(subst $$,\$$,$@) 

$(INSTALL_WWWDIR)/apt/%: aptui/%
	@echo "Installing $<"
	-mkdir -p $(patsubst %/,%,$(dir $@))
	$(INSTALL_DATA) $(subst $$,\$$,$<) $(subst $$,\$$,$@) 

$(INSTALL_WWWDIR)/aptb/%: aptuib/%
	@echo "Installing $<"
	-mkdir -p $(patsubst %/,%,$(dir $@))
	$(INSTALL_DATA) $(subst $$,\$$,$<) $(subst $$,\$$,$@) 

$(INSTALL_DIR)/opsdir/www/%.html: %.html htmlinstall
	@echo "Installing $<"
	-mkdir -p $(patsubst %/,%,$(dir $@))
	$(HTMLINSTALL) $(subst $$,\$$,$<) $(subst $$,\$$,$@) 

$(INSTALL_DIR)/opsdir/www/%: %
	@echo "Installing $<"
	-mkdir -p $(patsubst %/,%,$(dir $@))
	$(INSTALL_DATA) $(subst $$,\$$,$<) $(subst $$,\$$,$@) 

$(INSTALL_DIR)/opsdir/www/webssh/%: %
	@echo "Installing $<"
	-mkdir -p $(patsubst %/,%,$(dir $@))
	$(INSTALL_DATA) $(subst $$,\$$,$<) $(subst $$,\$$,$@) 

clean:		clean-subdirs
distclean:	distclean-subdirs

# How to recursively descend into subdirectories to make general
# targets such as `all'.
%.MAKE:
	@$(MAKE) -C $(dir $@) $(basename $(notdir $@))
%-subdirs: $(addsuffix /%.MAKE,$(SUBDIRS)) ;

.PHONY:	$(SUBDIRS)
