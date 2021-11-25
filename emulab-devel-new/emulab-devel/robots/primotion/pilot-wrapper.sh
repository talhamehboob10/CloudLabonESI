#! /usr/bin/perl -w

#
# Copyright (c) 2005 University of Utah and the Flux Group.
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
use POSIX qw(setsid);

sub usage()
{
    print "Usage: pilot-wrapper\n";
    exit(1);
}
my $optlist = "";
my $PIDFILE = "/var/run/pilot-wrapper.pid";
my $LOGFILE = "/var/emulab/logs/pilot-wrapper.log";
my $childpid;

#
# Turn off line buffering on output
#
$| = 1;

# Drag in path stuff so we can find emulab stuff.
BEGIN { require "/etc/emulab/paths.pm"; import emulabpaths; }

# Change to the directory where the pilot's config file is.
chdir("/etc/emulab");

#
# Load the OS independent support library. It will load the OS dependent
# library and initialize itself. 
# 
use libsetup;
# use libtmcc;
use libtestbed;

#
# Must be root.
# 
if ($UID != 0) {
    die("*** $0:\n".
	"    Must be root to run this script!\n");
}

# Signal handler to initiate cleanup in parent and the children.
sub Pcleanup($)
{
    my ($signame) = @_;

    $SIG{TERM} = 'IGNORE';

    if (defined($childpid)) {
	system("kill $childpid");
	waitpid($childpid, 0);
    }
    unlink $PIDFILE;
    exit(0);
}

# Daemonize;
if (TBBackGround($LOGFILE)) {
    sleep(1);
    exit(0);
}

#
# Write our pid into the pid file so we can be killed later. 
#
system("echo '$PID' > $PIDFILE") == 0 or
    die("*** $0:\n".
	"    Could not create $PIDFILE!");

# Okay, cleanup function.
$SIG{TERM} = \&Pcleanup;

# Fully disconnect from bootup. 
setsid();

# Loop forever, restarting pilot if it ever dies.
while (1) {
    $childpid = fork();

    die("*** $0:\n".
	"    Could not fork!\n")
	if ($childpid < 0);

    if ($childpid == 0) {
	sleep(1);

	exec("$BINDIR/garcia-pilot -d -l /var/emulab/logs/pilot.log");
	die("*** $0:\n".
	    "    Could not exec garcia-pilot!\n");
    }
    waitpid($childpid, 0);

    sleep(3);

    $retval = system("$BINDIR/brainstem-reset");
    if ($retval != 0) {
	print "WARNING: brainstem reset failed ($retval)!!!\n";
    }
    
    sleep(3);
}
exit(0);
