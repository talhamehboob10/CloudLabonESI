#!/usr/bin/perl -w
#
# Copyright (c) 2000-2013 University of Utah and the Flux Group.
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
# Bake the control node. Not much to it.
#
sub usage()
{
    print STDERR "Usage: bakectrl.pl [-d] [-s] <filename> <pubkey>\n";
    exit(-1);
}
my $optlist	= "ds";
my $debug	= 0;
my $snapshot    = 0;

# Locals
my $MNTPOINT	= "/mnt";

# Protos
sub Fatal($);

# un-taint path
$ENV{'PATH'} = '/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/site/bin';
delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};

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
if (defined($options{"d"})) {
    $debug = 1;
}
if (defined($options{"s"})) {
    $snapshot = 1;
}
usage()
    if (@ARGV != 2);
my $filename = $ARGV[0];
my $pubkey   = $ARGV[1];
if (! -e $filename) {
    Fatal("$filename does not exist");
}
if (! -e $pubkey) {
    Fatal("$pubkey does not exist");
}

#
# Make sure mounted.
#
if (! -e "$MNTPOINT/etc") {
    system("mount $MNTPOINT") == 0
	or Fatal("Could not mount $MNTPOINT");
}
if (! -e "$MNTPOINT/usr/bin") {
    system("mount $MNTPOINT/usr") == 0
	or Fatal("Could not mount $MNTPOINT/usr");
}

#
# Read in the variables file. 
#
my %configvars = ("address"    => undef,
		  "netmask"    => undef,
		  "gateway"    => undef,
		  "domain"     => undef,
		  "forwarders" => undef,
		  "hostname"   => undef,
		  "timezone"   => undef,
		  "rootpswd"   => undef);

open(CN, $filename)
    or Fatal("Could not open $filename: $!");
while (<CN>) {
    if ($_ =~ /^([-\w]*)\s*=\s*(.*)$/) {
	my $key = $1;
	my $val = $2;
	if ($val =~ /^'(.*)'$/) {
	    $val = $1;
	}
	elsif ($val =~ /^"(.*)"$/) {
	    $val = $1;
	}
	$configvars{$key} = "$val";
    }
}
close(CN);

foreach my $key (keys(%configvars)) {
    Fatal("$key is not defined!")
	if (!defined($configvars{$key}));
}

#
# A bunch of stuff.
#
my $interfaces = "$MNTPOINT/etc/network/interfaces.local";
print "Updating $interfaces\n";
open(FF, "> $interfaces")
    or fatal("Could not open $interfaces for writing: $!");
print FF "iface eth0 inet static\n";
print FF "    address " . $configvars{"address"} . "\n";
print FF "    netmask " . $configvars{"netmask"} . "\n";
print FF "    gateway " . $configvars{"gateway"} . "\n";
close(FF);

my $resolv = "$MNTPOINT/etc/resolv.conf";
print "Updating $resolv\n";
open(FF, "> $resolv")
    or fatal("Could not open $resolv for writing: $!");
print FF "search ". $configvars{"domain"} . "\n";
if (defined($configvars{"forwarders"})) {
    foreach my $forwarder (split(/[\s,]+/, $configvars{"forwarders"})) {
	print FF "nameserver $forwarder\n";
    }
}
print FF "nameserver 155.98.32.70\n";
close(FF);

my $hostname = "$MNTPOINT/etc/hostname";
print "Updating $hostname\n";
system("echo '" . $configvars{"hostname"} . "' > $hostname") == 0
    or Fatal("Could not create $hostname");

my $hostsfile = "$MNTPOINT/etc/hosts";
print "Updating $hostsfile\n";
open(FF, "> $hostsfile")
    or fatal("Could not open $hostsfile for writing: $!");
print FF "127.0.0.1\tlocalhost\n";
print FF "# These never change.\n";
print FF "10.1.1.253\tprocurve1\n";
print FF "10.2.1.253\tprocurve1-alt\n";
print FF "10.3.1.253\tprocurve2\n";
print FF "# Change this line for each rack.\n";
print FF $configvars{"address"} . "\t" . $configvars{"hostname"} . "\n";
close(FF);

my $localtime = "$MNTPOINT/etc/localtime";
print "Updating $localtime\n";
system("echo '" . $configvars{"timezone"} . "' > $localtime") == 0
    or Fatal("Could not create $localtime");

my $timezone = "$MNTPOINT/etc/timezone";
my $tzfile   = "$MNTPOINT/usr/share/zoneinfo/" . $configvars{"timezone"};
print "Updating $timezone\n";
if (! -e $tzfile) {
    Fatal("$tzfile does not exist");
}
system("/bin/cp -pf $tzfile $timezone") == 0
    or Fatal("Could not copy $tzfile to $timezone");

print "Setting root password\n";
my $salt = "";
for (my $i = 0; $i < 8; $i++) {
    $salt .= ('.', '/', 0..9, 'A'..'Z', 'a'..'z')[rand 64];
}
my $encrypted = crypt($configvars{"rootpswd"}, "\$6\$${salt}\$");
system("chroot $MNTPOINT /usr/sbin/usermod -p '$encrypted' root") == 0
    or Fatal("Could not set root password");

print "Creating new ssh host keys\n";
unlink("$MNTPOINT/etc/ssh/ssh_host_key");
system("chroot $MNTPOINT ssh-keygen -q ".
       "-t rsa1 -b 1024 -f /etc/ssh/ssh_host_key -N ''") == 0
    or Fatal("Could not create ssh_host_key");
unlink("$MNTPOINT/etc/ssh/ssh_host_dsa_key");
system("chroot $MNTPOINT ssh-keygen -q ".
       "-t dsa -f /etc/ssh/ssh_host_dsa_key -N ''") == 0
    or Fatal("Could not create ssh_host_dsa_key");
unlink("$MNTPOINT/etc/ssh/ssh_host_ecdsa_key");
system("chroot $MNTPOINT ssh-keygen -q ".
       "-t ecdsa -f /etc/ssh/ssh_host_ecdsa_key -N ''") == 0
    or Fatal("Could not create ssh_host_ecdsa_key");

if (-e "$MNTPOINT/etc/lastadmin") {
    my $lastadmin = `cat $MNTPOINT/etc/lastadmin`;
    chomp($lastadmin);
    if ($lastadmin ne "") {
	print "Removing previous admin: $lastadmin\n";
	system("chroot $MNTPOINT /usr/local/bin/mkadmin.pl -r $lastadmin") == 0
	    or Fatal("Could not add admin user");
    }
    unlink("$MNTPOINT/etc/lastadmin");
}

if (exists($configvars{"adminuser"})) {
    my $admin = $configvars{"adminuser"};
    print "Adding admin user $admin\n";
    system("/bin/cp -f $pubkey $MNTPOINT/tmp/key.pub") == 0
	or Fatal("Could not copy $pubkey to $MNTPOINT/tmp");
    system("chroot $MNTPOINT ".
	   "/usr/local/bin/mkadmin.pl $admin /tmp/key.pub")
	== 0 or Fatal("Could not add admin user");
    system("echo '$admin' > $MNTPOINT/etc/lastadmin");
}

exit(0)
    if (!$snapshot);

print "Unmounting filesystem ...\n";
system("/bin/sync");

system("/bin/umount $MNTPOINT/usr $MNTPOINT") == 0
    or Fatal("Could unmount $MNTPOINT");

system("imagezip -o /dev/sdb /scratch/control.ndz") == 0
    or Fatal("Could not imagezip disk");

system("mount $MNTPOINT") == 0
    or Fatal("Could not remount $MNTPOINT");
system("mount $MNTPOINT/usr") == 0
    or Fatal("Could not remount $MNTPOINT/usr");

exit(0);

sub Fatal($)
{
    my ($msg) = @_;

    die("*** $0:\n".
	"    $msg\n");
}

