#
# Copyright (c) 2007 University of Utah and the Flux Group.
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

# Run in directory of monitor.
# Usage: run-fake.sh <path-to-logs>
#
# Example:
#
# run-fake.sh /proj/tbres/exp/pelab-generated/logs/elab-1

python monitor.py --mapping=$1/local/logs/ip-mapping.txt --experiment=foo/bar \
	--ip=127.0.0.1 --initial=$1/local/logs/initial-conditions.txt --fake \
	< $1/local/logs/libnetmon.out
