#
# Copyright (c) 2009 University of Utah and the Flux Group.
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
my @pairList = (1, 2, 5, 10, 15, 20, 25, 30, 35);

my $i = 0;
for ($i = 0; $i < scalar(@pairList); ++$i)
{
    my $pairs = $pairList[$i];
    system("ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "
	   . "vhost-0.virt$pairs.tbres.emulab.net "
	   . "'perl /proj/tbres/duerig/virt/copy-single-delay.pl $pairs'");
}
