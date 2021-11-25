#
# Copyright (c) 2010 University of Utah and the Flux Group.
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

#/usr/testbed/bin/tevc -e tbres/pelab-generated now elabc-elab-1 modify dest=10.0.0.2 delay=$1
#/usr/testbed/bin/tevc -e tbres/pelab-generated now elabc-elab-2 modify dest=10.0.0.1 delay=$1
#/usr/testbed/bin/tevc -e tbres/pelab-generated now elabc-elab-1 modify dest=10.0.0.2 bandwidth=$2
#/usr/testbed/bin/tevc -e tbres/pelab-generated now elabc-elab-2 modify dest=10.0.0.1 bandwidth=$2
#/usr/testbed/bin/tevc -e tbres/pelab-generated now elabc-elab-1 modify dest=10.0.0.2 lpr=0.0
#/usr/testbed/bin/tevc -e tbres/pelab-generated now elabc-elab-2 modify dest=10.0.0.1 lpr=0.0
/usr/testbed/bin/tevc -e tbres/pelab-generated now plabc-plab-1 modify dest=10.1.0.2 delay=$1
/usr/testbed/bin/tevc -e tbres/pelab-generated now plabc-plab-2 modify dest=10.1.0.1 delay=$1
/usr/testbed/bin/tevc -e tbres/pelab-generated now plabc-plab-1 modify dest=10.1.0.2 bandwidth=$2
/usr/testbed/bin/tevc -e tbres/pelab-generated now plabc-plab-2 modify dest=10.1.0.1 bandwidth=$2
/usr/testbed/bin/tevc -e tbres/pelab-generated now plabc-plab-1 modify dest=10.1.0.2 lpr=0.0
/usr/testbed/bin/tevc -e tbres/pelab-generated now plabc-plab-2 modify dest=10.1.0.1 lpr=0.0

#/usr/testbed/bin/tevc -e tbres/pelab now rlink-router0 modify dest=10.4.0.1 delay=$1
#/usr/testbed/bin/tevc -e tbres/pelab now rlink-router1 modify dest=10.1.0.1 delay=$1
#/usr/testbed/bin/tevc -e tbres/pelab now rlink-router0 modify dest=10.4.0.1 bandwidth=$2
#/usr/testbed/bin/tevc -e tbres/pelab now rlink-router1 modify dest=10.1.0.1 bandwidth=$2

#/usr/testbed/bin/tevc -e tbres/pelab now rlink-router0 modify dest=10.5.0.1 delay=$1
#/usr/testbed/bin/tevc -e tbres/pelab now rlink-router1 modify dest=10.2.0.1 delay=$1
#/usr/testbed/bin/tevc -e tbres/pelab now rlink-router0 modify dest=10.5.0.1 bandwidth=$2
#/usr/testbed/bin/tevc -e tbres/pelab now rlink-router1 modify dest=10.2.0.1 bandwidth=$2

#/usr/testbed/bin/tevc -e tbres/pelab now rlink-router0 modify delay=$1
#/usr/testbed/bin/tevc -e tbres/pelab now rlink-router1 modify delay=$1
#/usr/testbed/bin/tevc -e tbres/pelab now rlink-router0 modify bandwidth=$2
#/usr/testbed/bin/tevc -e tbres/pelab now rlink-router1 modify bandwidth=$2





