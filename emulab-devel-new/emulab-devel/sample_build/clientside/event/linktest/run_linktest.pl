#!/usr/bin/perl -wT
#
# Copyright (c) 2000-2021 University of Utah and the Flux Group.
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
use strict;
use Getopt::Std;
use English;
use POSIX;

#
# XXX config stuff that does not belong on the client-side.
# Since run_linktest is typically run on ops instead of a client, I'll live.
#
my $TB            = "/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build";
my $CLIENT_BINDIR = "/usr/local/etc/emulab";
my $EVENTSERVER   = "event-server";
my $PROJROOT      = "/proj";
my $NOSHAREDFS	  = "0";
my $NODELOGDIR	  = "/var/emulab/logs";
#
# Wrapper for running the linktest daemon. This script is currently
# setup so it can run on either ops or from an experimental node.
#
sub usage()
{
    print "Usage: run_linktest.pl ".
	  "[-q] [-r] [-d level] [-t timeout] [-v] [-s server] [-p port] [-k keyfile] [-l level] [-o logfile] [-N] -e pid/eid\n".
	  "Use -q for quick termination mode, which skips the Bandwidth test\n".
	  "Use -r to report results, but not errors\n" .
          "Use -v for verbose feedback messages\n" .
	  "Use -t <time> to set a timeout in seconds\n" .
	  "Use -N to use a per-node directory for data collection\n" .
	  "   (default is to use a shared NFS directory).\n";
	     
    exit(1);
}
my $optlist = "vqrd:s:p:k:e:L:l:o:t:N";
my $debug   = 0;
my $verbose = 0;
my $timeout = 0;
my $reportonly = 0;
my $server;
my $keyfile;
my $port;
my $pid;
my $eid;
my $logfile;
my $child_pid;
my $startAt = 1; # default start level
my $stopAt = 4 ; # default stop level

my $nodelogdir = "";
if ($NOSHAREDFS) {
    # Must use node-local logdir if there is no shared FS
    $nodelogdir = $NODELOGDIR;
}

# Local goo
my $LTEVENT     = "$CLIENT_BINDIR/ltevent";
my $LOGHOLE     = "$TB/bin/loghole";
my $LTEVENTOPS  = "$TB/libexec/ltevent";
my $STOPEVENT   = "STOP"; # XXX Left in here for backwards compat.
my $COMPLETEEVENT = "COMPLETE";
my $KILLEVENT   = "KILL";
my $REPORTEVENT   = "REPORT";

#
# This script should be run as a real person!
#
if (! $EUID) {
    die("*** $0:\n".
	"    This script should not be run as root!\n");
}

# un-taint path
$ENV{'PATH'} = '/bin:/usr/bin:/usr/local/bin';
delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};

$| = 1; #Turn off line buffering on output

#
# Make sure log files get created so project members can delete them!
#
umask(0002);

#
# Parse command arguments. Once we return from getopts, all that should be
# left are the required arguments.
#
my %options = ();
if (! getopts($optlist, \%options)) {
    print "error: cannot parse options\n";
    usage();
}
if (@ARGV) {
    print "error: extra arguments\n";
    usage();
}
if (defined($options{"d"})) {
    $debug = $options{"d"};
    if ($debug =~ /^([\w]+)$/) {
	$debug = $1;
    }
    else {
	die("*** $0:\n".
	    "    Bad data in debug: $debug\n");
    }
}
if (defined($options{"v"})) {
    $verbose = 1;
}
if (defined($options{"t"})) {
    $timeout = $options{"t"};
    if ($timeout =~ /^([\w]+)$/) {
	$timeout = $1;
    }
    else {
	die("*** $0:\n".
	    "    Bad data in timeout: $timeout\n");
    }
}
if (defined($options{"L"})) {
    $startAt = $options{"L"};
    if ($startAt =~ /^(\d)$/) {
	$startAt = $1;
    }
    else {
	die("*** $0:\n".
	    "    Bad data in start level: $startAt\n");
    }
}
if (defined($options{"l"})) {
    $stopAt = $options{"l"};
    if ($stopAt =~ /^(\d)$/) {
	$stopAt = $1;
    }
    else {
	die("*** $0:\n".
	    "    Bad data in level: $stopAt\n");
    }
}

if (defined($options{"q"})) {
    # ignore if via -l they are already in quick mode.
    if($stopAt > 3) { 
	$stopAt = 3; 
    }
}
if (defined($options{"s"})) {
    $server = $options{"s"};
    if ($server =~ /^([-\w\.]+)$/) {
	$server = $1;
    }
    else {
	die("*** $0:\n".
	    "    Bad data in server: $server\n");
    }
}
if (defined($options{"k"})) {
    $keyfile = $options{"k"};
    if ($keyfile =~ /^([-\w\.\/]+)$/) {
	$keyfile = $1;
    }
    else {
	die("*** $0:\n".
	    "    Bad data in keyfile: $keyfile\n");
    }
}
if (defined($options{"o"})) {
    $logfile = $options{"o"};
    if ($logfile =~ /^([-\w\.\/]+)$/) {
	$logfile = $1;
    }
    else {
	die("*** $0:\n".
	    "    Bad data in logfile: $logfile\n");
    }
}
if (defined($options{"N"})) {
    $nodelogdir = $NODELOGDIR;
}
if (defined($options{"p"})) {
    $port = $options{"p"};
    if ($port =~ /^(\d+)$/) {
	$port = $1;
    }
    else {
	die("*** $0:\n".
	    "    Bad data in port: $port\n");
    }
}
if (defined($options{"r"})) {
    $reportonly = 1;
}
if (defined($options{"e"})) {
    ($pid,$eid) = split(/\//, $options{"e"});
}
else {
    usage();
}

#
# Untaint args.
#
if ($pid =~ /^([-\w]+)$/) {
    $pid = $1;
}
else {
    die("*** $0:\n".
	"    Bad data in pid: $pid\n");
}
if ($eid =~ /^([-\@\w]+)$/) {
    $eid = $1;
}
else {
    die("*** $0:\n".
	"    Bad data in eid: $eid\n");
}


#
# Default to the standard event server.
#
if (!defined($server)) {
    $server = "$EVENTSERVER";
}

#
# Assorted paths
#
my $expdata_path = "$PROJROOT/$pid/exp/$eid/tbdata";

# These days, must use a keyfile!
if (!defined($keyfile)) {
    $keyfile = "$expdata_path/eventkey";
}
# path to linktest data.
my $linktest_path = "$expdata_path/linktest";
if ($NOSHAREDFS || $nodelogdir ne "") {
    #
    # We have to make the log directory since it is not in a shared FS
    # (normally the "master" linktest node would do this).
    #
    if (-e $linktest_path) {
	die("Path $linktest_path is not a directory\n") 
	    unless -d $linktest_path;
	system("rm -rf $linktest_path/*");
    } else {
	# 
	# The shared path does not exist, create it.
	#
	mkdir($linktest_path, 0775)
	    || die("Could not create directory $linktest_path: $!");
    }
}

# send the startup event.
my $args = starter();
# event arguments
$args .=  " -x START";
$args .= " STARTAT=$startAt STOPAT=$stopAt";
$args .= " DEBUG=$debug"
    if ($debug);
$args .= " REPORTONLY=1"
    if ($reportonly);

#
# All nodes in the experiment need to agree on local logging or not
# so we force it from here. We don't want clients using heuristics to
# decide this.
#
if ($nodelogdir) {
    $args .= " SHAREDDIR=0 LOGDIR=$nodelogdir";
} else {
    $args .= " SHAREDDIR=1";
}

#
# Remain compatible with older linktests.  This will turn off the ARP
# test and force an otherwise pointless barrier synch.
#
$args .= " DOARP=0 COMPAT=1.1";

system($args);
if ($?) {
    die("*** $0:\n".
	"    Error running '$args'\n");
}

print "Starting linktest at " . &TBTimeStamp() . "\n";
print "Quick termination requested.\n"
    if (defined($options{"q"}));
print "Debug mode requested.\n"
    if ($debug);

sub handler($)
{
    my ($signame) = @_;

    $SIG{INT}  = 'IGNORE';
    $SIG{TERM} = 'IGNORE';
    $SIG{HUP}  = 'IGNORE';

    sleep(2);
    &kill_linktest_run;

    if (defined($child_pid)) {
	kill('TERM', $child_pid);
	waitpid($child_pid, 0);
	undef($child_pid);
    }

    if ($signame eq 'ALRM') {
	print "*** Linktest timer has expired, aborting the run.\n";
	&analyze(1);
    }
    else {
	print "*** Linktest has been aborted\n";
	&run_loghole;
    }
    exit(1);
}

#
# Now that linktest has started, wait for events to be reported
# by ltevent. It will print out the event followed by args,
# which are informational. The events sent are KILL, STOP, COMPLETE and REPORT.
#
$args = starter();
$args .= " -w";
if (($child_pid = fork())) {
    my $exitval;

    #
    # Install signal handlers to wait for a kill or a timeout.
    # If the process is killed, kill Linktest!
    #
    $SIG{INT}  = \&handler;
    $SIG{TERM} = \&handler;
    $SIG{HUP}  = \&handler;
    
    #
    # Set timeout behavior if requested.
    #
    if ($timeout) {
	$SIG{ALRM} = \&handler;
	alarm($timeout);
    }
    waitpid($child_pid, 0);
    $exitval = $?;
    alarm 0;
    if ($exitval) {
	&run_loghole;
	
	exit($exitval >> 8);
    }
    exit(&analyze(0));
}
else {
    my $ltpid;
    my $exitval = 0;

    #
    # Open child process to read in the output from ltevent,
    # and just print out the return values for feedback.
    #
    $SIG{TERM} = sub {
	if (defined($ltpid)) {
	    kill('TERM', $ltpid);
	    waitpid($ltpid, 0);
	    exit(0);
	}
    };

    $ltpid = open(LTC, "$args |");
    if (! $ltpid) {
	die("*** $0:\n".
	    "    Error running '$args'\n");
    }
    while(<LTC>) {
	chomp;
	if(/(\w+)\s?(.*)/) {
	    my $eventtype = $1;
	    my $eventargs = $2;
	    if (($eventtype eq $STOPEVENT) ||
		($eventtype eq $COMPLETEEVENT)) {
		print "Linktest completed at " . &TBTimeStamp() . "\n"
		    if($verbose);
		last;
	    }
	    elsif ($eventtype eq $KILLEVENT) {
		print("Linktest has been cancelled due to a timeout ".
		      "or unrecoverable error.\n");
		$exitval = 1;
		last;
	    } else {
		#
		# Print out report messages if in verbose mode.
		#
		print $eventargs . "\n"
		    if ($verbose);
	    }
	} else {
	    # parse error, exit.
	    print "error parsing: " . $_ . "\n";
	    $exitval = -1;
	    last;
	}
    }
    kill('TERM', $ltpid);
    close(LTC);
    exit($exitval);
}

#
# If we don't have a shared filesystem where nodes can put their data,
# we must collect it from each node first using loghole.
#
sub getdata($) {
    my ($datadir) = @_;
    my $tmpdir = "$expdata_path/tmp";

    &run_loghole($datadir, $tmpdir);

    # XXX move stuff up from where loghole leaves it
    my @dir_contents;
    opendir(DIR, "$tmpdir") ||
	die("*** $0:\n".
	    "    Cannot open tmp results dir $tmpdir\n");
    my @nodes = grep(/^[-\w]+$/, readdir(DIR));
    closedir(DIR);
    foreach my $node (@nodes) {
	if ($node =~ /^([-\w]+)$/) {
	    $node = $1;
	}
	my $nodedir = "$tmpdir/$node/$datadir";
	if (!opendir(DIR, $nodedir)) {
	    # do not even complain about delay nodes
	    if ($node !~ /^tbs?delay/) {
		print "*** Cannot find results for $node, ignoring...\n";
	    }
	    next;
	}
	my @files = grep(/\.fatal$|\.error$/, readdir(DIR));
	closedir(DIR);
	foreach my $file (@files) {
	    if ($file =~ /^([-\w\.\/]+)$/) {
		$file = $1;
		rename("$nodedir/$file", "$linktest_path/$file") ||
		    die("*** $0:\n".
			"    Cannot move $nodedir/$file to $linktest_path\n");
	    }
	}
    }
    system("rm -rf $tmpdir");
}

#
# Spits out the results from the Linktest path,
# with a return code that indicates whether errors were found
# by Linktest on the nodes.
# 
sub analyze($) {
    my ($timedout) = @_;    
    
    if ($nodelogdir) {
	&getdata("$nodelogdir/linktest");
    }

    my @dir_contents;
    opendir(DIR, $linktest_path) ||
	die("*** $0:\n".
	    "    Cannot open results dir $linktest_path\n");
    @dir_contents = grep(/\.fatal$|\.error$/, readdir(DIR));
    closedir(DIR);

    unlink($logfile)
	if (defined($logfile));

    return 0
	if (! (scalar(@dir_contents) || $timedout));

    &run_loghole
	if (! $timedout);

    if (!defined($logfile)) {
	print "*************************************************************";
	print "****\n";
	print "***************** Linktest Error Reports ********************";
	print "****\n\n";
    }

    if ($timedout && defined($logfile)) {
	my $msg = "Linktest timer expired, run was aborted\n".
	          "Gathering results generated before the timer expired\n".
		  "\n";

	system("echo '$msg' > $logfile");
    }

    foreach my $file (@dir_contents) {
	# Hmm, need to taint check the filenames. Ick.
	if ($file =~ /^([-\w\.\/]+)$/) {
	    $file = $1;
	}
	else {
	    die("*** $0:\n".
		"    Bad data in filename: $file\n");
	}
	if (defined($logfile)) {
	    open LOG_FILE, ">>$logfile" || 
		die "Could not open $logfile for append: $!";

	    open NODE_TRACE, "$linktest_path/$file" || 
		die "Could not open $file for read: $!";
	    while(<NODE_TRACE>) {
		print LOG_FILE $_;
	    }
	    close NODE_TRACE;
	    close LOG_FILE;
	} else {
	    system("/bin/cat $linktest_path/$file");
	}
    }
    if (!defined($logfile)) {
	print "*************************************************************";
	print "****\n";
    }
    return scalar(@dir_contents);
}

# Initial part of command string to ltevent.
sub starter {
    my $cmd;

    if (-x $LTEVENTOPS) {
	$cmd = $LTEVENTOPS;
    }
    else {
	$cmd = $LTEVENT;
    }
    $cmd .= " -s $server -e $pid/$eid";
    $cmd .= " -p $port"
	if (defined($port));
    $cmd .= " -k $keyfile"
	if (defined($keyfile));
    
    return $cmd
}

# Sub to kill off linktest on the nodes.
sub kill_linktest_run {
    my $args = starter();
    $args .= " -x $KILLEVENT";
    system($args);
    if ($?) {
	die("*** $0:\n".
	    "    Error running '$args'\n");
    }
}

sub run_loghole(;$$) {
    my ($remdir,$localdir) = @_;

    # defaults
    if (!$remdir || !$localdir) {
	$remdir = "/var/emulab/logs";
	$localdir = "$PROJROOT/$pid/exp/$eid/tbdata/ltlogs";
    }
    print "Downloading logs ... patience please.\n";
    system("rm -rf $localdir");
    system("mkdir -p $localdir");
    system("chmod 775 $localdir");
    system("$LOGHOLE -e $pid/$eid -q sync -P -n -l $localdir -r $remdir");
    # XXX attempt to make sure directory can be removed by project leader
    system("chmod -R g+w $localdir");
}

sub TBTimeStamp {
    return POSIX::strftime("%H:%M:%S", localtime());
}
