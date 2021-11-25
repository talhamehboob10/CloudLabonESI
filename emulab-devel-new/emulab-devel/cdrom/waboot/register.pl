#!/usr/bin/perl -w
#
# Copyright (c) 2000-2003 University of Utah and the Flux Group.
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

#
# This file goes in /usr/site/sbin on the CDROM.
#
use English;
use Getopt::Std;
use Fcntl;
use IO::Handle;
use Socket;

#
# Get the instructions script from NetBed central and run it. This is
# basically wrapper that does no real work, but just downloads and
# runs a script, then reboots the nodes if that script ran okay.
#
sub usage()
{
    print("Usage: register.pl <bootdisk> <ipaddr>\n");
    exit(-1);
}
my  $optlist = "";

#
# Catch ^C and exit with error. This will cause the CDROM to boot to
# the login prompt, but thats okay.
# 
sub handler () {
    $SIG{INT} = 'IGNORE';
    exit(1);
}
$SIG{INT}  = \&handler;

#
# Turn off line buffering on output
#
STDOUT->autoflush(1);
STDERR->autoflush(1);

#
# Untaint the environment.
# 
$ENV{'PATH'} = "/tmp:/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:".
    "/usr/local/bin:/usr/site/bin:/usr/site/sbin";
delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};

#
# Definitions.
#
my $WWW         = "https://www.emulab.net";
#my $WWW        = "http://golden-gw.ballmoss.com:8080/~stoller/testbed";
#my $WWW        = "https://www.emulab.net/~stoller/www";
my $cdkeyfile	= "/etc/emulab.cdkey";
my $pubkey      = "/etc/emulab_pubkey.pem";
my $wget	= "wget";
my $logfile     = "/tmp/register.log";
my $scriptfile  = "/tmp/netbed-setup.pl";
my $sigfile     = "/tmp/netbed-setup.pl.sig";
my $tmpfile	= "/tmp/foo.$$";

#
# Function prototypes
#
sub fatal($);
sub mysystem($);
sub Prompt($$;$);

#
# Locals. 
# 
my $cdkey;

#
# Parse command arguments. Once we return from getopts, all that should be
# left are the required arguments.
#
%options = ();
if (! getopts($optlist, \%options)) {
    usage();
}
if (@ARGV != 2) {
    usage();
}
my $rawbootdisk = $ARGV[0];
my $IP = $ARGV[1];

#
# See if we want to continue. Useful for debugging.
# 
print "\n";
if (! (Prompt("Dance with Netbed?", "Yes", 15) =~ /yes/i)) {
    exit(0);
}

#
# The cdkey describes the cd. We send it along in the request.
# 
if (! -s $cdkeyfile) {
    fatal("No CD key on the CD!");
}
$cdkey = `cat $cdkeyfile`;
chomp($cdkey);

	
#
# Get the script from netbed central. We have to be able to get it,
# otherwise we are hosed, so just keep trying. If the user hits ^C
# on the console, this script will exit and the node will try to
# go to single user mode (asking for passwword of course). 
#
while (1) {
    my $emulab_status;
    my ($url, $md5, $sig);

    while (1) {
	print "Checking in at Netbed Central for instructions ...\n";
    
	mysystem("$wget -q -O $tmpfile ".
		 "'${WWW}/cdromcheckin.php3?cdkey=$cdkey&needscript=1'");
    
	if (!$?) {
	    last;
	}

	print "Error getting instructions. Will try again in one minute ...\n";
	sleep(60);
    }
    if (! -s $tmpfile) {
	fatal("Could not get valid instructions from $WWW!");
    }

    #
    # Parse the response. We get back the URL and the signature, as well as
    # a status code.
    #
    if (! open(INSTR, $tmpfile)) {
	fatal("$tmpfile could not be opened for reading: $!");
    }
    while (<INSTR>) {
	chomp();
        SWITCH1: {
	    /^emulab_status=(.*)$/ && do {
		$emulab_status = $1;
		last SWITCH1;
	    };
	    /^URL=(.*)$/ && do {
		$url = $1;
		last SWITCH1;
	    };
	    # Leave this in to avoid error below.
	    /^MD5=(.*)$/ && do {
		$md5 = $1;
		last SWITCH1;
	    };
	    /^SIG=(.*)$/ && do {
		$sig = $1;
		last SWITCH1;
	    };
	    print STDERR "Ignoring unknown instruction: $_\n";
	}
    }
    close(INSTR);

    if (defined($emulab_status)) {
	if ($emulab_status) {
	    fatal("Bad response code from Netbed: $emulab_status!");
	}
    }
    else {
	fatal("Improper instructions; did not include netbed status!");
    }
    fatal("Improper instructions; did not include URL!")
	if (!defined($url));
    fatal("Improper instructions; did not include digital signature!")
	if (!defined($sig));

    while (1) {
	print "Downloading script from Netbed Central ...\n";

	mysystem("$wget -nv -O $scriptfile $url");	
	if (!$?) {
	    last;
	}

	print "Error getting scriptfile. Will try again in 15 seconds!\n";
	sleep(15);
    }

    while (1) {
	print "Downloading script signature from Netbed Central ...\n";

	mysystem("$wget -nv -O $sigfile $sig");	
	if (!$?) {
	    last;
	}

	print "Error getting signature. Will try again in 15 seconds!\n";
	sleep(15);
    }

    #
    # Check the digital signature. 
    #
    print "Checking digital signature of the scriptfile.\n";

    my $cmd  = "openssl dgst -sha1 -verify $pubkey ".
	"-signature $sigfile $scriptfile";
    my $hval = `$cmd`;
    chomp($hval);

    #
    # Yep, its amazing. Instead of exiting with status, this stupid
    # program always exits with 0, so have to check the output. 
    #
    last
	if ($hval eq "Verified OK");

    print("Bad signature! Will try again in 15 seconds!\n");
    sleep(15);
}

#
# Run the script. It must succeed or we are hosed!
#
mysystem("chmod +x $scriptfile");
system("$scriptfile $rawbootdisk $IP") == 0
    or fatal("$scriptfile failed!");

#
# One last chance to hold things up.
# 
if (Prompt("Reboot from ${rawbootdisk}?", "Yes", 10) =~ /yes/i) {
    mysystem("shutdown -r now");
    fatal("Failed to reboot!")
	if ($?);
    sleep(100000);
}
exit(0);

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
sub mysystem($)
{
    my ($command) = @_;

    if (defined($logfile)) {
	system("echo \"$command\" >> $logfile");
	system("($command) >> $logfile 2>&1");
    }
    else {
	print "Command: '$command\'\n";
	system($command);
    }
    return $?;
}

#
# Spit out a prompt and a default answer. If optional timeout supplied,
# then wait that long before returning the default. Otherwise, wait forever.
#
sub Prompt($$;$)
{
    my ($prompt, $default, $timeout) = @_;

    if (!defined($timeout)) {
	$timeout = 10000000;
    }

    print "$prompt";
    if (defined($default)) {
	print " [$default]";
    }
    print ": ";

    eval {
	local $SIG{ALRM} = sub { die "alarm\n" }; # NB: \n required
	
	alarm $timeout;
	$_ = <STDIN>;
	alarm 0;
    };
    if ($@) {
	if ($@ ne "alarm\n") {
	    die("Unexpected interrupt in prompt\n");
	}
	#
	# Timed out.
	#
	print "\n";
	return $default;
    }
    return undef
	if (!defined($_));
	
    chomp();
    if ($_ eq "") {
	return $default;
    }

    return $_;
}

