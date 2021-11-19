#!/usr/bin/perl -w
#
# Copyright (c) 2000-2002, 2004 University of Utah and the Flux Group.
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
use English;

my $TB     = "/test";
my $cvsupd = "/usr/local/sbin/cvsupd";
my $log    = "cvsupd.log";

chdir("$TB/sup") or
    die("Could no chdir to $TB/sup: $!\n");

my (undef,undef,$unix_uid) = getpwnam("nobody") or
    die("No such user nobody\n");
my (undef,undef,$unix_gid) = getgrnam("nobody") or
    die("No such group nobody\n");

if (! -e $log) {
    system("touch $log");
    chown($unix_uid, $unix_gid, $log);
}

# Flip to the user/group nobody.
$EGID = $GID = $unix_gid;
$EUID = $UID = $unix_uid;

exec "$cvsupd -l $log -C 100 -b .";
die("*** $0:\n".
    "    Could not exec cvsupd: $!\n");
