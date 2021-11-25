#!/usr/bin/perl -wT
#
# Copyright (c) 2008-2015 University of Utah and the Flux Group.
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
# Miscellaneous OS-independent utility routines.
#

package libutil;
use Exporter;
@ISA    = "Exporter";
@EXPORT = qw( ipToMac macAddSep fatal mysystem mysystem2 ExecQuiet
              findDNS setState isRoutable findDomain convertToMebi
              ipToNetwork CIDRmask untaintNumber untaintHostname
	      GenFakeMac
            );

use libtmcc;
use Socket;


# Constants
my $IPREGEX = '^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$';

sub setState($) {
    my ($state) = @_;

    libtmcc::tmcc(TMCCCMD_STATE(),"$state");
}

sub ipToMac($) {
    my $ip = shift;

    return sprintf("0000%02x%02x%02x%02x",$1,$2,$3,$4)
	if ($ip =~ /$IPREGEX/);

    return undef;
}

sub macAddSep($;$) {
    my ($mac,$sep) = @_;
    if (!defined($sep)) {
	$sep = ":";
    }

    return "$1$sep$2$sep$3$sep$4$sep$5$sep$6"
	if ($mac =~ /^([0-9a-zA-Z]{2})([0-9a-zA-Z]{2})([0-9a-zA-Z]{2})([0-9a-zA-Z]{2})([0-9a-zA-Z]{2})([0-9a-zA-Z]{2})$/);

    return undef;
}

#
# Is an IP routable?
#
sub isRoutable($)
{
    my ($IP)  = @_;
    my ($a,$b,$c,$d) = ($IP =~ /$IPREGEX/);

    #
    # These are unroutable:
    # 10.0.0.0        -   10.255.255.255  (10/8 prefix)
    # 172.16.0.0      -   172.31.255.255  (172.16/12 prefix)
    # 192.168.0.0     -   192.168.255.255 (192.168/16 prefix)
    #

    # Easy tests.
    return 0
	if (($a eq "10") ||
	    ($a eq "192" && $b eq "168"));

    # Lastly
    return 0
	if (inet_ntoa((inet_aton($IP) & inet_aton("255.240.0.0"))) eq
	    "172.16.0.0");

    return 1;
}

# Return network portion of IP address
sub ipToNetwork($$) {
    my ($ip, $mask) = @_;

    return undef 
	unless defined($ip) && defined($mask) 
	&& $ip =~ /$IPREGEX/ && $mask =~ /$IPREGEX/;

    return inet_ntoa(inet_aton($ip) & inet_aton($mask));
}

# Given a dot-decimal netmask, return the equivalent CIDR netmask
sub CIDRmask($) {
    my $mask = shift;

    return undef
	unless $mask =~ /$IPREGEX/;

    my $cidrmask = unpack("%32b*", inet_aton($mask));

    return $cidrmask;
}

#
# XXX boss is the DNS server for everyone
#
sub findDNS($)
{
    my ($ip) = @_;

    my ($bossname,$bossip) = libtmcc::tmccbossinfo();

    return undef
	unless $bossip =~ /$IPREGEX/;

    return $bossip;
}

#
# Get our domain
#
sub findDomain()
{
    import emulabpaths;

    return undef
	if (! -e "$BOOTDIR/mydomain");
    
    my $domain = `cat $BOOTDIR/mydomain`;
    chomp($domain);
    return $domain;
}

#
# Convert most storage size specs to Mebibytes
#
sub convertToMebi($) {
    my $insize = shift;
    my $outsize;

    if (!defined($insize) || !$insize) {
        return -1;
    }

  CSIZE:
    for ($insize) {
        /^(\d+)B?$/ && do {
            $outsize = $1 / 2**20;
            last CSIZE;
        };
        /^(\d+(\.\d+)?)KB?$/ && do {
            $outsize = $1 * 10**3 / 2**20;
            last CSIZE;
        };
        /^(\d+(\.\d+)?)KiB?$/ && do {
            $outsize = $1 / 2**10;
            last CSIZE;
        };
        /^(\d+(\.\d+)?)MB?$/ && do {
            $outsize = $1 * 10**6 / 2**20;
            last CSIZE;
        };
        /^(\d+(\.\d+)?)MiB?$/ && do {
            $outsize = $1;
            last CSIZE;
        };
        /^(\d+(\.\d+)?)GB?$/ && do {
            $outsize = $1 * 10**9 / 2**20;
            last CSIZE;
        };
        /^(\d+(\.\d+)?)GiB?$/ && do {
            $outsize = $1 * 2**10;
            last CSIZE;
        };
        /^(\d+(\.\d+)?)TB?$/ && do {
            $outsize = $1 * 10**12 / 2**20;
            last CSIZE;
        };
        /^(\d+(\.\d+)?)TiB?$/ && do {
            $outsize = $1 * 2**20;
            last CSIZE;
        };
        # Default (bad size spec)
        $outsize = -1;
    }

    return $outsize;
}

sub untaintNumber($) {
    my $number = shift;

    return undef
	unless defined($number);

    # Tack on a '0' to a bare, leading decimal for the regex below.
    $number = $number =~ /^\./ ? "0" . $number : $number;

    $number =~ /^(\d+(\.\d+)?)$/;
    my $retval = $1;

    return undef
	unless defined($retval);

    return $retval;
}

sub untaintHostname($) {
    my $name = shift;

    return undef
	unless defined($name);

    $name =~ /^([-\.\w]+)$/;
    my $retval = $1;

    return undef
	unless defined($retval);

    return $retval;
}


#
# Print error and exit.
#
sub fatal($)
{
    my ($msg) = @_;

    die("*** $0:\n".
	"    $msg\n");
}

#
# Run a command string, redirecting output to a logfile.
#
sub mysystem($;$)
{
    my ($command,$doecho) = @_;
    $doecho = 1 if (!defined($doecho));

    if ($doecho) {
	print STDERR "mysystem: '$command'\n";
    }

    system($command);
    if ($?) {
	fatal("Command failed: $? - $command");
    }
}
sub mysystem2($;$)
{
    my ($command,$doecho) = @_;
    $doecho = 1 if (!defined($doecho));

    if ($doecho) {
	print STDERR "mysystem: '$command'\n";
    }

    system($command);
    if ($?) {
	print STDERR "Command failed: $? - '$command'\n";
    }
}

sub ExecQuiet($)
{
    my ($command) = @_;

    print STDERR "ExecQuiet: '$command'\n";

    my $output    = "";
    
    #
    # This open implicitly forks a child, which goes on to execute the
    # command. The parent is going to sit in this loop and capture the
    # output of the child. We do this so that we have better control
    # over the descriptors.
    #
    my $pid = open(PIPE, "-|");
    if (!defined($pid)) {
	print STDERR "ExecQuiet Failure; popen failed!\n";
	return undef;
    }
    if ($pid) {
	while (<PIPE>) {
	    $output .= $_;
	}
	close(PIPE);
    }
    else {
	open(STDERR, ">&STDOUT");
	exec($command);
	die("ExecQuiet: exec('$command') failed!\n");
    }
    print STDERR $output;
    if ($?) {
	print STDERR "Command failed: $?\n";
    }
    return $output;
}

#
# Generate a hopefully unique mac address that is suitable for use
# on a shared node where uniqueness matters.
#
sub GenFakeMac()
{
    my $mac;
    
    #
    # Random number for lower 4 octets.
    # 
    my $ran=`/bin/dd if=/dev/urandom count=32 bs=1 2>/dev/null | /usr/bin/sha256sum`;
    return undef
	if ($?);
    
    if ($ran =~ /^\w\w\w(\w\w\w\w\w\w\w\w\w\w)/)  {
	$mac = $1;
    }

    #
    # Set the "locally administered" bit, good practice.
    #
    return "02" . $mac;
}

# Must be last thing in file.
1;
