#!/bin/sh
#
# Copyright (c) 2000-2002 University of Utah and the Flux Group.
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
. /etc/emulab/paths.sh

ostype=`uname -s`

if [ "$ostype" = "FreeBSD" ];  then
	USERADD="pw useradd"
elif [ "$ostype" = "Linux" ];  then
	USERADD="useradd"
else
	echo "Unsupported OS: $ostype"
	exit 1
fi

$USERADD emulabman -u 65520 -g bin -m -s /bin/tcsh -c "Emulab Man"

if [ ! -d ~emulabman ]; then
	mkdir ~emulabman
	chown emulabman ~emulabman
	chgrp bin ~emulabman
fi

if [ ! -d ~emulabman/.ssh ]; then
	cd ~emulabman
	chmod 755 .
	mkdir .ssh
	chown emulabman .ssh
	chgrp bin .ssh
	chmod 700 .ssh
	cd .ssh
	cp $ETCDIR/emulabkey authorized_keys
	chown emulabman authorized_keys
	chgrp bin authorized_keys
	chmod 644 authorized_keys
fi

exit 0
