#
# Copyright (c) 2005-2006 University of Utah and the Flux Group.
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

test_rcmd 'tar', [], 'node', 'test -e /usr/tar.gz';
test_rcmd 'tar.Z', ['tar'], 'node', 'test -e /usr/tar.Z/hw.txt';
test_rcmd 'tgz', ['tar'], 'node', 'test -e /usr/tgz/hw.txt';
test_rcmd 'tar.gz', ['tar'], 'node', 'test -e /usr/tar.gz/hw.txt';
test_rcmd 'tar.bz2', ['tar'], 'node', 'test -e /usr/tar.bz2/hw.txt';
test_rcmd 'startcmd', [], 'node', 'test -e /tmp/startcmd-ok';
print "Sleeping 5 seconds...\n";
sleep 5;
test_rcmd 'prog_simple', [], 'node', 'test -e /tmp/prog_simple-ok';
test_rcmd 'prog_env', [], 'node', "test -e /tmp/testenv-$parms{pid}-$parms{eid}";
test_cmd 'reboot', [], "node_reboot -w -e $parms{pid},$parms{eid}";

