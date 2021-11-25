#!/usr/bin/perl -w
#
# Copyright (c) 2000-2012 University of Utah and the Flux Group.
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
use Getopt::Std;

#
# Create an admin user on the control node. 
#
sub usage()
{
    print STDERR "Usage: mkadmin.pl <uid> <pubkeyfile>\n";
    print STDERR "       mkadmin.pl [-r] <uid>\n";
    exit(-1);
}
my $optlist	= "r";
my $remove	= 0;
my $HOMEDIR     = "/home";
my $pubkey;

#
# Turn off line buffering on output
#
$| = 1;

#
# Parse command arguments.
#
my %options = ();
if (! getopts($optlist, \%options)) {
    usage();
}
if (exists($options{"r"})) {
    $remove = 1;
}
if ($remove) {
    usage()
	if (@ARGV != 1);
}
else {
    usage()
	if (@ARGV != 2);

    $pubkey = $ARGV[1];
    die("$pubkey does not exist\n")
	if (! -e $pubkey);
}
my $uid = $ARGV[0];

sub mysystem($)
{
    my ($command) = @_;

    system($command);
    if ($?) {
	print STDERR "Command failed: $? - '$command'\n";
    }
}

if ($remove) {
    mysystem("deluser --remove-home $uid");
    exit(1)
	if ($?);
    exit(0);
}

#
# Add the user; if it already exists too bad.
#
mysystem("adduser --disabled-password --gecos '$uid' --ingroup root $uid");
exit(1)
    if ($?);

# Need to be in this group too, for sudo.
mysystem("adduser $uid admin");
exit(1)
    if ($?);

#
# Create and populate the .ssh dir. 
#
mysystem("mkdir $HOMEDIR/$uid/.ssh")
    if (! -e "$HOMEDIR/$uid/.ssh");
exit(1)
    if ($?);

mysystem("cp -pf $pubkey $HOMEDIR/$uid/.ssh/authorized_keys");
exit(1)
    if ($?);

mysystem("chmod 700 $HOMEDIR/$uid/.ssh");
mysystem("chmod 600 $HOMEDIR/$uid/.ssh/authorized_keys");
mysystem("chown -R $uid:root $HOMEDIR/$uid/.ssh");
