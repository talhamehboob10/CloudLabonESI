#!/usr/bin/perl -w
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

use English;

#
# Remove all traces of elvin from a client
#
my @BSDPKGS = (
    'elvind-4.0.3',
    'libelvin-4.0.3_2'
);

my @BSDFILES = (
    '/usr/local/etc/rc.d/elvind.sh',
    '/usr/local/bin/elvin-config',
    '/usr/local/bin/ep',
    '/usr/local/bin/ec',
    '/usr/local/etc/elvind*',
    '/usr/local/include/elvin',
    '/usr/local/info/elvin*',
    '/usr/local/lib/libvin4*',
    '/usr/local/lib/nls/msg/elvin*',
    '/usr/local/man/man*/elvin*',
    '/usr/local/man/man1/ec.1',
    '/usr/local/man/man1/ep.1',
    '/usr/local/man/man8/epf.8',
    '/usr/local/libexec/elvind',
    '/usr/local/libexec/epf',
    '/var/log/elvind.log'
);

my @LINUXFILES = (
    '/etc/rc.d/*/*elvin',
    '/usr/local/bin/elvin-config',
    '/usr/local/bin/ep',
    '/usr/local/bin/ec',
    '/usr/local/etc/elvind*',
    '/usr/local/include/elvin',
    '/usr/local/info/elvin*',
    '/usr/local/lib/libvin4*',
    '/usr/local/lib/nls/msg/elvin*',
    '/usr/local/man/man*/elvin*',
    '/usr/local/man/man1/ec.1',
    '/usr/local/man/man1/ep.1',
    '/usr/local/man/man8/epf.8',
    '/usr/local/sbin/elvind',
    '/usr/local/sbin/epf'
);

if ($UID ne 0) {
    print STDERR "You will want to be doing this as root ya know!\n";
    exit(1);
}

my $isbsd = 0;
if (-e "/usr/sbin/pkg_delete") {
    $isbsd = 1;
}

print "Bye, bye elvin...\n";
if ($isbsd) {
    # disable elvind logging in syslog.conf
    system("sed -i '' -e '/elvind/d' /etc/syslog.conf");

    # remove any packages?
    foreach my $pkg (@BSDPKGS) {
	if (!system("pkg_info -e $pkg")) {
	    print "removing $pkg package...\n";
	    system("pkg_delete -f $pkg");
	}
    }

    # remove known files
    my @list = `ls -d @BSDFILES 2>/dev/null`;
    print "removing: @list\n";
    chomp(@list);
    my $lstr = join(' ', @list);
    system("rm -rf $lstr");
    @list = `ls -d @BSDFILES 2>/dev/null`;
    print "what's left: @list\n";
} else {
    # remove any rpms?

    my @list = `ls -d @LINUXFILES 2>/dev/null`;
    print "removing: @list\n";
    chomp(@list);
    my $lstr = join(' ', @list);
    system("rm -rf $lstr");
    @list = `ls -d @LINUXFILES 2>/dev/null`;
    print "what's left: @list\n";
}

print "Elvin has left the building (you KNEW that was coming!)\n";
exit 0;
