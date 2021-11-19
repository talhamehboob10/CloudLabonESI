#
# Copyright (c) 2000-2005, 2008 University of Utah and the Flux Group.
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
# This makefile is different than all the others...
# 
# It is intended to be run in place in the cvs tree to update the files,
# and doesn't install or build anything else. This is why it doesn't go
# through configure, etc.
#

# The easy way: do 'gmake all'
# You can also run the individual targets too.

all: db-create db-create-errorlog db-fill sitevars old-db-create old-db-create-errorlog

db-create:
	@rm -f ./.tmp-db-create.sql ./.tmp-create-diff
	@mysqldump -d tbdb > ./.tmp-db-create.sql
	@-diff ./database-create.sql ./.tmp-db-create.sql > ./.tmp-create-diff
	@if test -s ./.tmp-create-diff; \
	then \
		cat ./.tmp-create-diff; \
		echo "NOTE: Don't forget to update database-migrate.txt!"; \
		mv ./.tmp-db-create.sql ./database-create.sql; \
	fi
	@rm -f ./.tmp-create-diff ./.tmp-db-create.sql

db-create-errorlog:
	@rm -f ./.tmp-db-create-errorlog.sql ./.tmp-create-diff-errorlog
	@mysqldump -d errorlog > ./.tmp-db-create-errorlog.sql
	@-diff ./database-create-errorlog.sql ./.tmp-db-create-errorlog.sql > ./.tmp-create-diff-errorlog
	@if test -s ./.tmp-create-diff-errorlog; \
	then \
		cat ./.tmp-create-diff-errorlog; \
		echo "NOTE: Don't forget to update database-migrate.txt!"; \
		mv ./.tmp-db-create-errorlog.sql ./database-create-errorlog.sql; \
	fi
	@rm -f ./.tmp-create-diff-errorlog ./.tmp-db-create-errorlog.sql

old-db-create:
	cp ./database-create.sql ./.tmp-db-create.sql
	sed -i '' -e 's/ENGINE=MyISAM DEFAULT CHARSET=latin1/TYPE=MyISAM/' ./.tmp-db-create.sql
	sed -i '' -e 's/ default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP//' ./.tmp-db-create.sql
	mv ./.tmp-db-create.sql ./database-create-old.sql
	@rm -f ./.tmp-db-create.sql

old-db-create-errorlog:
	cp ./database-create-errorlog.sql ./.tmp-db-create-errorlog.sql
	sed -i '' -e 's/ENGINE=MyISAM DEFAULT CHARSET=latin1/TYPE=MyISAM/' ./.tmp-db-create-errorlog.sql
	sed -i '' -e 's/ default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP//' ./.tmp-db-create-errorlog.sql
	mv ./.tmp-db-create-errorlog.sql ./database-create-old-errorlog.sql
	@rm -f ./.tmp-db-create-errorlog.sql

db-fill:
	@/usr/testbed/sbin/wap /usr/testbed/sbin/export_tables \
	  > database-fill.sql

db-fill-dist: knowlbase
	@/usr/testbed/sbin/wap /usr/testbed/sbin/export_tables -i \
	  > database-fill.sql

sitevars:
	@mysqldump --skip-opt --skip-quote-names -t tbdb sitevariables > sitevars-create.sql 

knowlbase:
	@mysqldump -c -t tbdb knowledge_base_entries | sed -e 's,^INSERT,REPLACE,' > knowlbase-create.sql 

fwrules:
	@echo "*** Use 'gmake insertrules' in the firewall subdir to do this"

dist:	db-fill-dist

