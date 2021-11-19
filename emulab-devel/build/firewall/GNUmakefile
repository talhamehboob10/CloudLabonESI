#
# Copyright (c) 2000-2014 University of Utah and the Flux Group.
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

SRCDIR		= ../../firewall
TESTBED_SRCDIR	= ../..
OBJDIR		= ..
SUBDIR		= firewall
TBDB		= tbdb
MDOPTS		= --compact --skip-extended-insert --no-create-info --skip-set-charset

FW_SCRIPTS	= initfwvars.pl
FW_FILES	= open.sql closed.sql basic.sql elabinelab.sql \
		  iptables-vlan-open.sql iptables-vlan-closed.sql \
		  iptables-vlan-basic.sql iptables-vlan-elabinelab.sql \
		  iptables-domU-open.sql iptables-domU-closed.sql \
		  iptables-domU-basic.sql \
		  iptables-dom0-open.sql iptables-dom0-closed.sql \
		  iptables-dom0-basic.sql

include $(OBJDIR)/Makeconf

#
# Force dependencies on the scripts so that they will be rerun through
# configure if the .in file is changed.
# 
all: $(FW_SCRIPTS) $(FW_FILES)

include $(TESTBED_SRCDIR)/GNUmakerules

iptables-vlan-%.sql: genconfig-iptables.pl
	$(SRCDIR)/genconfig-iptables.pl -f $(SRCDIR)/iptables-fw-rules -M $* > $@

iptables-dom0-%.sql: genconfig-iptables.pl iptables-fw-dom0-rules
	$(SRCDIR)/genconfig-iptables.pl -t iptables-dom0 -f $(SRCDIR)/iptables-fw-dom0-rules -M $* > $@

iptables-domU-%.sql: genconfig-iptables.pl iptables-fw-domU-rules
	$(SRCDIR)/genconfig-iptables.pl -t iptables-domU -f $(SRCDIR)/iptables-fw-domU-rules -M $* > $@

%.sql: genconfig.pl
	$(SRCDIR)/genconfig.pl -f $(SRCDIR)/fw-rules -M $* > $@

insertvars: initfwvars.pl dumpoldvars
	chmod +x ./initfwvars.pl
	./initfwvars.pl

insertrules: $(FW_FILES) dumpoldrules
	cat $(FW_FILES) | mysql $(TBDB)
	echo 'FW rules updated in DB'

dumpold: dumpoldvars dumpoldrules

dumpoldvars:
	@if ! `mysqldump $(MDOPTS) -w "1 order by name" $(TBDB) default_firewall_vars >vars.old`; then \
		echo -n '*** default_firewall_vars table does not exist, '; \
		echo 'see sql/database-migrate.txt'; \
		exit 1; \
	fi

dumpoldrules:
	@if ! `mysqldump $(MDOPTS) -w "1 order by type,style,ruleno" $(TBDB) default_firewall_rules >rules.old`; then \
		echo -n '*** default_firewall_rules table does not exist, '; \
		echo 'see sql/database-migrate.txt'; \
		exit 1; \
	fi

dumpnew: dumpnewvars dumpnewrules

dumpnewvars: initfwvars.pl
	chmod +x ./initfwvars.pl
	initfwvars.pl -n >vars.new

dumpnewrules: $(FW_FILES)
	cat open.sql closed.sql basic.sql elabinelab.sql | \
	    grep -v 'DELETE FROM' >rules.new
	cat iptables-vlan-open.sql iptables-vlan-closed.sql \
	    iptables-vlan-basic.sql iptables-vlan-elabinelab.sql | \
	    grep -v 'DELETE FROM' >>rules.new
	cat iptables-dom0-open.sql iptables-dom0-closed.sql \
	    iptables-dom0-basic.sql | \
	    grep -v 'DELETE FROM' >>rules.new
	cat iptables-domU-open.sql iptables-domU-closed.sql \
	    iptables-domU-basic.sql | \
	    grep -v 'DELETE FROM' >>rules.new

dump: dumpvars dumprules
dumpvars: dumpoldvars dumpnewvars
dumprules: dumpoldrules dumpnewrules

clean:
	rm -f *.old *.new *.sql initfwvars.pl

