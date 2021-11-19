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
my $pairs = $ARGV[0];

my $count = $pairs * 2;

system("sudo killall delay-agent");
my $i = 0;
for ($i = 1; $i <= $count; ++$i)
{
    system("sudo cp /proj/tbres/duerig/delay-agent/src/testbed/event/delay-agent/new/delay-agent /vz/private/$i/usr/local/etc/emulab");
    print "Copying $pairs-$i\n";
}
