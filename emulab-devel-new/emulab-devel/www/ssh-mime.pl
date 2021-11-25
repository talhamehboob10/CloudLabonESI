#!/usr/bin/perl -w
#
# Copyright (c) 2000-2003, 2006 University of Utah and the Flux Group.
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
# This is a helper program for your web browser. It allows you to ssh
# to an experimental node by clicking on a menu option in the shownode
# page. Its extremely helpful with jailed nodes, where sshd is either
# running on another port, or on a private IP. Please see the Emulab FAQ
# for instructions on how to install this helper program. 
#
# Obviously, it helps to have an ssh agent running.
# 
sub usage()
{
    print(STDERR "ssh-mime.pl <control-file>\n");
    exit(1);
}
my $optlist = "";
my $config;

# Locals
my $hostname;
my $gateway;
my $port    = "";
my $login   = "";

# Protos
sub DoOSX();
sub StartXterm();
sub StartOSXTerm();

#
# Turn off line buffering on output
#
$| = 1;

#
# Parse command arguments. Once we return from getopts, all that should be
# left are the required arguments.
#
%options = ();
if (! getopts($optlist, \%options)) {
    usage();
}
if (@ARGV != 1) {
    usage();
}
$config = $ARGV[0];

#
# Open up the config file. It tells us what to do.
#
open(CONFIG, "< $config")
    or die("Could not open config file $config: $!\n");

while (<CONFIG>) {
    chomp();
    SWITCH1: {
	/^port:\s*(\d+)$/ && do {
	    $port = "-p $1";
	    last SWITCH1;
	};
	/^hostname:\s*([-\w\.]+)$/ && do {
	    $hostname = $1;
	    last SWITCH1;
	};
	/^gateway:\s*([-\w\.]+)$/ && do {
	    $gateway = $1;
	    last SWITCH1;
	};
	/^login:\s*([-\w]+)$/ && do {
	    $login = "-l $1";
	    last SWITCH1;
	};
    }
}
close(CONFIG);

#
# Must have a hostip. Port is optional.
#
if (!defined($hostname)) {
    die("Config file must specify a hostname\n");
}
if ($OSNAME eq "darwin") {
    # Path is all screwey on the Mac.
    $ENV{'PATH'} .= ":/usr/X11R6/bin";

    # Cause its a folder action ...
    system("/bin/rm -f $config");
    
    DoOSX();
    exit(0);
}
StartXterm();
exit(0);

#
# Start up the xterms.
#
sub StartXterm()
{
    if (!defined($gateway)) {
	exec "xterm -T $hostname -e ssh $port $login $hostname ".
	    "\|\| read userinput";
    }
    else {
	my $sshcmd = "ssh -o StrictHostKeyChecking=no $port";

	# for IXPs at Utah Emulab
	if ($gateway =~ /^ixp\d+-gw\.emulab\.net$/) {
	    $sshcmd = "telnet -l root";
	}

	exec "xterm -T $hostname -e ssh $login -tt $gateway ".
	    "$sshcmd $hostname ".
	    "\|\| read userinput";
    }
}

#
# Mac OSX support; try to deduce the DISPLAY variable.
#
sub DoOSX()
{
    my $display;
    
    for (my $i = 0; $i < 20; $i++) {
	if (-e "/tmp/.X${i}-lock") {
	    $display = ":${i}.0";
	    last;
	}
    }
    if (!defined($display)) {
	StartOSXTerm();
	return;
    }

    $ENV{'DISPLAY'} = $display;

    # Tell X to activate.
    system("osascript -e 'tell application \"X11\" to activate'");
    StartXterm();
}

#
# This is going to start up Terminal.app ... but it depends on you
# having your SSH agent available. The easies way to do that is to
# go here: http://www.sshkeychain.org ... install this application
# and following the instructions to make sure it is launched when
# you log in. 
#
sub StartOSXTerm()
{
    my $command;
    
    if (!defined($gateway)) {
	$command = "ssh $port $login $hostname";
    }
    else {
	my $sshcmd = "ssh -o StrictHostKeyChecking=no $port";

	# for IXPs at Utah Emulab
	if ($gateway =~ /^ixp\d+-gw\.emulab\.net$/) {
	    $sshcmd = "telnet -l root";
	}

	$command = "ssh $login -tt $gateway ".
	    "$sshcmd $hostname";
    }
    
    exec "osascript -e 'tell application \"Terminal\" \n".
	 " activate \n".
	 " do script with command \"$command ; exit\" \n".
	 " tell window 1 \n".
	 "    set custom title to \"$hostname\" \n".
	 " end tell \n".
	 "end tell'";
}
