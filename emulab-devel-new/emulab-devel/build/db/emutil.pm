#!/usr/bin/perl -w
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
# Utility routines for Emulab.
#
package emutil;
use strict;
use Exporter;
use SelfLoader;
use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter SelfLoader);
@EXPORT = qw(TBDB_CHECKDBSLOT_NOFLAGS TBDB_CHECKDBSLOT_WARN
	     TBDB_CHECKDBSLOT_ERROR TBcheck_dbslot TBFieldErrorString
	     TBGetUniqueIndex ParRun VersionInfo UpdateVersionInfo
	     SpanningTree GenFakeMac BackTraceOnWarning PassWordHash
             SSHwithTimeout TBDateStringGMT TBDateStringLocal TBDateStringUTC
	     runBusyLoop
	     MapEventType MapEventObjectType MapEventTriggerType ValidUUID
);

use emdb;
use English;
use Carp;
use Date::Parse;
use Time::Local;
use Data::Dumper;
use Socket;
use POSIX qw(:signal_h);

# Configure variables.
my $TB           = "/users/mshobana/emulab-devel/build";
my $OPSVM_ENABLE = 0;
my $WITHZFS      = 1;
my $CHFLAGS      = "/bin/chflags";
my $DISABLEFLAGS = 0;

#
# Store up the list of caches to flush
#
my @ourcaches = ();

sub AddCache($)
{
    my ($ref) = @_;

    push(@ourcaches, $ref);
}
sub FlushCaches()
{
    foreach my $ref (@ourcaches) {
	%$ref = ();
    }
}
sub DumpCaches()
{
    require Devel::Size;

    my $total = 0;
    foreach my $cache (@ourcaches) {
	my $subtotal = 0;
	my @values = values(%{$cache});
	next
	    if (!@values);
	print STDERR "Dumping cache:\n";
	foreach my $ref (@values) {
	    my $size = Devel::Size::total_size($ref);
	    
	    print STDERR " $ref: $size\n";
	    $subtotal += $size;
	    $total += $size;
	}
	my $realsize = Devel::Size::total_size($cache);
	print STDERR "Cache total: $subtotal, $realsize\n";
    }
     if ($total) {
	my $realsize = Devel::Size::total_size(\@ourcaches);
	print STDERR "All caches total: $total, $realsize\n";
    }
}

#
# Support for checking field values against what is specified.
#
use vars qw(%DBFieldData $DBFieldErrstr);

%DBFieldData   = ();
$DBFieldErrstr = "";

#
# A helper function for checking lossrates. Bad place for this, I know.
# Needs to be before the __DATA__ cause we used defined() on it. Sigh.
#
sub _checklossrate($)
{
    my ($token) = @_;

    return 1
	if ("$token" eq "0");

    # floating point, no exponent. Stole this out of the perl tutorial.
    if (! ($token =~ /^[+-]?(\d+\.\d+|\d+\.|\.\d+)([eE][+-]?\d+)?$/)) {
	$DBFieldErrstr = "Improper floating number";
	return 0;
    }
    if ($token > 1.0) {
	$DBFieldErrstr = "Too big; must be < 1.0";
	return 0;
    }
    if ($token < 0.0) {
	$DBFieldErrstr = "Too small; must be > 0.0";
	return 0;
    }
    if ($token > 0.0 && $token < 0.000001) {
	$DBFieldErrstr = "Too small; must be >= 0.000001";
	return 0;
    }
    return 1;
}

1;


# Constants for checkslot code.
sub TBDB_CHECKDBSLOT_NOFLAGS()	{ 0x0; }
sub TBDB_CHECKDBSLOT_WARN()	{ 0x1; }
sub TBDB_CHECKDBSLOT_ERROR()	{ 0x2; }

sub TBFieldErrorString() { return $DBFieldErrstr; }

#
# Download all data from the DB and store in hash for latter access.
#
sub TBGrabFieldData()
{
    %DBFieldData = ();

    my $query_result =
	emdb::DBQueryFatal("select * from table_regex");

    while (my %row = $query_result->fetchhash()) {
	my $table_name  = $row{"table_name"};
	my $column_name = $row{"column_name"};

	$DBFieldData{$table_name . ":" . $column_name} =
	    { "check"       => $row{"check"},
	      "check_type"  => $row{"check_type"},
	      "column_type" => $row{"column_type"},
	      "min"         => $row{"min"},
	      "max"         => $row{"max"}
	    };
    }
}

#
# Return the field data for a specific table/slot. If none, return the default
# entry.
#
# The top level entry defines some stuff that is not to be overidden by the
# redirected entries. For example, the top level entry is the only place we
# can specify a field is optional when inserting a record. We could do this
# with default entries in the DB table defintion, but I do not like that idea.
# The min/max lengths also override, unless they are both zero in which case
# let the first non-zero defs set them.
#
sub TBFieldData($$;$)
{
    my ($table, $column, $flag) = @_;
    my $toplevel;
    my $fielddata;

    if (! %DBFieldData) {
	TBGrabFieldData();
    }
    my $key = $table . ":" . $column;

    while (exists($DBFieldData{$key})) {
	$fielddata = $DBFieldData{$key};

	#
	# See if a redirect to another entry.
	#
	if ($fielddata->{"check_type"} eq "redirect") {
	    if (!defined($toplevel)) {
		$toplevel = $fielddata;
	    }

	    $key = $fielddata->{"check"};
#	    print STDERR "Redirecting to $key for $table/$column!\n";
	    next;
	}
	last;
    }
    # Resort to a default entry.
    if (!defined($fielddata)) {
	$DBFieldErrstr = "Error-checking pattern missing from the database";
	
	if (defined($flag)) {
	    if ($flag & TBDB_CHECKDBSLOT_WARN()) {
		print STDERR "*** $0:\n" .
		             "    WARNING: No slot data for $table/$column!\n";
	    }
	    return undef
		if ($flag & TBDB_CHECKDBSLOT_ERROR());
	}
	$fielddata = $DBFieldData{"default:default"};
    }
    # Return both entries.
    if (defined($toplevel) &&
	($toplevel->{"min"} || $toplevel->{"max"})) {
	return ($fielddata, $toplevel);
    }
    return ($fielddata);
}

#
# Generic wrapper to check a slot.
#
sub TBcheck_dbslot($$$;$)
{
    my ($token, $table, $column, $flag) = @_;
    
    $DBFieldErrstr = "Unknown Error";

    my ($fielddata,$toplevel) = TBFieldData($table, $column, $flag);

    return 0
	if (!defined($fielddata));

    my $check       = $fielddata->{"check"};
    my $check_type  = $fielddata->{"check_type"};
    my $column_type = $fielddata->{"column_type"};
    my $min         = (defined($toplevel) ?
		       $toplevel->{"min"} : $fielddata->{"min"});
    my $max         = (defined($toplevel) ?
		       $toplevel->{"max"} : $fielddata->{"max"});

#    print STDERR "Using $check/$check_type/$column_type/$min/$max for ".
#	"$table/$column\n";

    #
    # Functional checks partly implemented. Needs work.
    #
    if ($check_type eq "function") {
	if (defined(&$check)) {
	    my $func = \&$check;
	    return &$func($token);   
	}
	else {
	    die("*** $0:\n" .
		"    Functional DB check not implemented: ".
		"$table/$column/$check\n");
	}
    }

    # Make sure the regex is anchored. Its a mistake not to be!
    $check = "^" . $check
	if (! ($check =~ /^\^/));

    $check = $check . "\$"
	if (! ($check =~ /\Q$/));

    # Check regex.
    if (! ("$token" =~ /$check/)) {
	$DBFieldErrstr = "Illegal Characters";
	return 0;
    }

    # Check min/max.
    if ($column_type eq "text") {
	my $len = length($token);

	# Any length is okay if no min or max. 
	return 1
	    if ((!($min || $max)) ||
		($len >= $min && $len <= $max));
	$DBFieldErrstr = "Too Short"
	    if ($min && $len < $min);
	$DBFieldErrstr = "Too Long"
	    if ($max && $len > $max);
    }
    elsif ($column_type eq "int" ||
	   $column_type eq "float") {
	# If both min/max are zero, then skip check; allow anything.
	return 1
	    if ((!($min || $max)) || ($token >= $min && $token <= $max));
	$DBFieldErrstr = "Too Small"
	    if ($min && $token < $min);
	$DBFieldErrstr = "Too Big"
	    if ($max && $token > $max);
    }
    else {
	die("*** $0:\n" .
	    "    Unrecognized column_type $column_type\n");
    }
    return 0;
}

#
# Return a unique index from emulab_indicies for the indicated name.
# Updates the index to be, well, unique.
# Eats flaming death on error.
#
# WARNING: this will unlock all locked tables, be careful where you call it!
#
sub TBGetUniqueIndex($;$$)
{
    my ($name, $initval, $nolock) = @_;

    return TBGetUniqueIndexNew($name, $initval, $nolock)
	if (1);

    #
    # Lock the table to avoid conflict, but not if the caller already did it.
    #
    $nolock = 0
	if (!defined($nolock));
    
    DBQueryFatal("lock tables emulab_indicies write")
	if (!$nolock);

    my $query_result =
	DBQueryFatal("select idx from emulab_indicies ".
		     "where name='$name'");
    my ($curidx) = $query_result->fetchrow_array();
    if (!defined($curidx)) {
	$curidx = (defined($initval) ? $initval : 1);
    }
    my $nextidx = $curidx + 1;

    DBQueryFatal("replace into emulab_indicies (name, idx) ".
		 "values ('$name', $nextidx)");
    DBQueryFatal("unlock tables")
	if (!$nolock);

    return $curidx;
}

sub TBGetUniqueIndexNew($;$$)
{
    my ($name, $initval, $nolock) = @_;
    $nolock = 0
	if (!defined($nolock));
    $initval = 1
	if (!defined($initval));
    
    #
    # Determine if the index exists, if not already in the table, then
    # we have to lock it and initialize.
    #
    my $query_result =
	DBQueryFatal("select idx from emulab_indicies ".
		     "where name='$name'");
    
    if (!$query_result->numrows) {
	DBQueryFatal("lock tables emulab_indicies write")
	    if (!$nolock);
	
	$query_result =
	    DBQueryFatal("select idx from emulab_indicies ".
			 "where name='$name'");

	if (!$query_result->numrows) {
	    DBQueryFatal("insert into emulab_indicies set ".
			 " name='$name',idx='$initval'");
	}
	DBQueryFatal("unlock tables")
	    if (!$nolock);
    }

    #
    # Once it exists, we can do this atomically.
    #
    DBQueryFatal("update emulab_indicies set idx=LAST_INSERT_ID(idx) + 1 ".
		 "where name='$name'");

    $query_result = DBQueryFatal("select LAST_INSERT_ID()");
    my ($curidx) = $query_result->fetchrow_array();
    return $curidx;
}

#
# A utility function for forking off a bunch of children and
# waiting for them.
#
# TODO: A fatal error will leave children. Need to catch that.
#
sub ParRun($$$@)
{
    my ($options, $pref, $function, @objects) = @_;
    my %children = ();
    my @results  = ();
    my $counter  = 0;
    my $signaled = 0;
    my $nosighup = 0;
    # We need this below.
    require event;

    # options.
    my $maxchildren = 10;
    my $maxwaittime = 200;

    if (defined($options)) {
	$maxchildren = $options->{'maxchildren'}
	    if (exists($options->{'maxchildren'}));
	$maxwaittime = $options->{'maxwaittime'}
	    if (exists($options->{'maxwaittime'}));
	$nosighup = $options->{'nosighup'}
	    if (exists($options->{'nosighup'}));
    }

    #
    # Set up a signal handler in the parent to handle termination.
    #
    my $coderef = sub {
	my ($signame) = @_;

	print STDERR "Caught SIG${signame} in $$! Killing parrun ...\n";

	$SIG{TERM} = 'IGNORE';
	$signaled = 1;

	foreach my $pid (keys(%children)) {
	    print STDERR "Sending HUP signal to $pid ...\n";
	    kill('HUP', $pid);
	}
	sleep(1);
    };
    local $SIG{QUIT} = $coderef;
    local $SIG{TERM} = $coderef;
    local $SIG{INT}  = $coderef;
    local $SIG{HUP}  = $coderef if (!$nosighup);

    #
    # Initialize return.
    #
    for (my $i = 0; $i < scalar(@objects); $i++) {
	$results[$i] = -1;
    }

    while ((@objects && !$signaled) || keys(%children)) {
	#
	# Something to do and still have free slots.
	#
	if (@objects && keys(%children) < $maxchildren && !$signaled) {
	    # Space out the invocation of child processes a little.
	    select(undef, undef, undef, 0.25);	    

	    my $newsigset = POSIX::SigSet->new(SIGQUIT,SIGINT,SIGTERM,SIGHUP);
	    my $oldsigset = POSIX::SigSet->new;
	    if (! defined(sigprocmask(SIG_BLOCK, $newsigset, $oldsigset))) {
		print STDERR "sigprocmask (BLOCK) failed!\n";
		return -1;
	    }
	    if (!$signaled) {
		#
		# Run command in a child process, protected by an alarm to
		# ensure that whatever happens is not hung up forever in
		# some funky state.
		#
		my $object = shift(@objects);
		my $syspid = fork();

		if ($syspid) {
		    #
		    # Just keep track of it, we'll wait for it finish down below
		    #
		    $children{$syspid} = [$object, $counter, time()];
		    $counter++;
		}
		else {
		    $SIG{TERM} = 'DEFAULT';
		    $SIG{QUIT} = 'DEFAULT';
		    $SIG{HUP}  = 'DEFAULT';
		    $SIG{INT}  = 'IGNORE';

		    # Unblock in child after resetting the handlers.
		    if (! defined(sigprocmask(SIG_SETMASK, $oldsigset))) {
			print STDERR "sigprocmask (UNBLOCK) failed!\n";
		    }
		
		    # So randomness is not the same in different children
		    srand();
		
		    # So we get the event system fork too ...
		    event::EventFork();
		    exit(&$function($object));
		}
	    }
	    # Unblock after critical section.
	    if (! defined(sigprocmask(SIG_SETMASK, $oldsigset))) {
		print STDERR "sigprocmask (UNBLOCK) failed!\n";
		return -1;
	    }
	}
	elsif ($signaled) {
	    my $childpid   = wait();
	    my $exitstatus = $?;

	    if (exists($children{$childpid})) {
		delete($children{$childpid});
	    }
	}
	else {
	    #
	    # We have too many of the little rugrats, wait for one to die
	    #
	    #
	    # Set up a timer - we want to kill processes after they
	    # hit timeout, so we find the first one marked for death.
	    #
	    my $oldest;
	    my $oldestpid = 0;
	    my $oldestobj;
	    
	    while (my ($pid, $aref) = each %children) {
		my ($object, $which, $birthtime) = @$aref;

		if ((!$oldestpid) || ($birthtime < $oldest)) {
		    $oldest    = $birthtime;
		    $oldestpid = $pid;
		    $oldestobj = $object;
		}
	    }

	    #
	    # Sanity check
	    #
	    if (!$oldest) {
		print STDERR 
		    "*** ParRun: ".
		    "Uh oh, I have no children left, something is wrong!\n";
	    }

	    #
	    # If the oldest has already expired, just kill it off
	    # right now, and go back around the loop
	    #
	    my $now = time();
	    my $waittime = ($oldest + $maxwaittime) - time();

	    #
	    # Kill off the oldest if it gets too old while we are waiting.
	    #
	    my $childpid = -1;
	    my $exitstatus = -1;

	    eval {
		local $SIG{ALRM} = sub { die "alarm clock" };

		if ($waittime <= 0) {
		    print STDERR
			"*** ParRun: timeout waiting for child: $oldestpid\n";
		    kill("TERM", $oldestpid);
		}
		else {
		    alarm($waittime);
		}
		$childpid = wait();
		alarm 0;
		$exitstatus = $?;
	    };
	    if ($@) {
		die unless $@ =~ /alarm clock/;
		next;
	    }

	    #
	    # Another sanity check
	    #
	    if ($childpid < 0) {
		print STDERR
		    "*** ParRun:\n".
		    "wait() returned <0, something is wrong!\n";
		next;
	    }

	    #
	    # Look up to see what object this was associated with - if we
	    # do not know about this child, ignore it
	    #
	    my $aref = $children{$childpid};
	    next unless @$aref;	
	    my ($object, $which, $birthtime) = @$aref;
	    delete($children{$childpid});
	    $results[$which] = $exitstatus;
	}
    }
    @$pref = @results
	if (defined($pref));
    return -1
	if ($signaled);
    return 0;
}

#
# Version Info
#
sub VersionInfo($)
{
    my ($name) = @_;

    my $query_result = 
	DBQueryWarn("select value from version_info ".
		    "where name='$name'");

    return undef
	if (!$query_result || !$query_result->numrows);

    my ($value) = $query_result->fetchrow_array();
    return $value;
}

#
# Version Info
#
sub UpdateVersionInfo($$)
{
    my ($name, $value) = @_;
    my $safe_name  = DBQuoteSpecial($name);

    if (!defined($value)) {
	return -1
	    if (!DBQueryWarn("delete from version_info ".
			     "where name=$safe_name"));
    }
    else {
	my $safe_value = DBQuoteSpecial($value);

	return -1
	    if (!DBQueryWarn("replace into version_info set ".
			     "  name=$safe_name, value=$safe_value"));
    }
    return 0;
}

#
# Run a command, being sure to capture all output. 
#
sub ExecQuiet($;$)
{
    #
    # Use a pipe read, so that we save away the output
    #
    my ($command, $verbose) = @_;
    my $output    = "";
    $verbose = 0 if (!defined($verbose));
    
    #
    # This open implicitly forks a child, which goes on to execute the
    # command. The parent is going to sit in this loop and capture the
    # output of the child. We do this so that we have better control
    # over the descriptors.
    #
    my $pid = open(PIPE, "-|");
    if (!defined($pid)) {
	print STDERR "ExecQuiet Failure; popen failed!\n";
	return -1;
    }
    
    if ($pid) {
	while (<PIPE>) {
	    $output .= $_;
	    print $_ if ($verbose);
	}
	close(PIPE);
    }
    else {
	open(STDERR, ">&STDOUT");
	exec($command);
    }
    return $output;
}
sub ExecVerbose($)
{
    return ExecQuiet($_[0], 1);
}

sub PipeCommand($$$)
{
    my ($command, $input, $pmsg) = @_;

    require Socket;
    import Socket qw(:DEFAULT);
    require IO::Handle;     # thousands of lines just for autoflush :-(
    
    if (! socketpair(CHILD, PARENT, AF_UNIX(), SOCK_STREAM(), PF_UNSPEC())) {
	print STDERR "*** PipeTo: Could not create socketpair\n";
	return undef;
    }
    CHILD->autoflush(1);
    PARENT->autoflush(1);

    my $childpid = fork();
    if (! $childpid) {
	close CHILD;

	#
	# Dup our descriptors to the parent, and exec the program.
	# The parent then talks to it read/write.
	#
	open(STDIN,  "<&PARENT") || die "Cannot redirect stdin";
	open(STDOUT, ">&PARENT") || die "Cannot redirect stdout";
	open(STDERR, ">&PARENT") || die "Cannot redirect stderr";

	exec($command);
	die("*** $0:\n".
	    "    exec '$command' failed: $!\n");
    }
    close PARENT;

    # Write input to the child.
    print CHILD $input;
    # Tell the process we are done writing. ie: Send it an EOF.
    shutdown(CHILD,1);
    
    my $output = "";
    while (<CHILD>) {
	$output .= $_;
    }
    close(CHILD);
    waitpid($childpid, 0);
    if ($?) {
	$$pmsg = "PipeCommand failed: '$command'";
	if ($output ne "") {
	    $$pmsg .= "\n" . $output;
	}
	return undef;
    }
    return $output;
}

#
# Given a set of edges: [[cisco1, cisco3], [cisco3, cisco4]].
# Return a spanning tree. Deadly simple algorithm. 
#
sub SpanningTree($)
{
    my ($edges)  = @_;
    my %vertices = ();
    my %edges    = ();
    my $maxloops = 1000;

    #
    # Get the unique set of vertices. Also form a hash of edges we can mark.
    #
    foreach my $edge (@$edges) {
	my ($a, $b) = @$edge;
	$vertices{$a} = 0
	    if (!exists($vertices{$a}));
	$vertices{$b} = 0
	    if (!exists($vertices{$b}));
	$edges{"$a:$b"} = 0;
    }
    #print Dumper(\%vertices);
    #print Dumper(\%edges);
    
    #
    # Pick the first vertex and mark it.
    #
    $vertices{(keys(%vertices))[0]} = 1;

    #
    # Loop according to Prims algorithm.
    #
    while ($maxloops) {
	$maxloops--;
	#
	# Get the set of marked vertices;
	#
	my %marked = ();
	foreach my $vertex (keys(%vertices)) {
	    $marked{$vertex} = 1
		if ($vertices{$vertex});
	}
	# Done if all vertices are marked.
	last
	    if (scalar(keys(%marked)) == scalar(keys(%vertices)));

	#
	# Find the first unmarked vertex that connects to any of the
	# marked ones. Mark that edge; that is an edge we want in the
	# final set.
	#
	foreach my $vertex (keys(%vertices)) {
	    next
		if ($marked{$vertex});

	    foreach my $marked (keys(%marked)) {
		if (exists($edges{"$vertex:$marked"})) {
		    $edges{"$vertex:$marked"} = 1;
		    $vertices{$vertex} = 1;
		    goto loop;
		}
		elsif (exists($edges{"$marked:$vertex"})) {
		    $edges{"$marked:$vertex"} = 1;
		    $vertices{$vertex} = 1;
		    goto loop;
		}
	    }
	}
      loop:
	#print Dumper(\%edges);
	#sleep(1);
    }
    if ($maxloops <= 0) {
	print STDERR "*** SpanningTree: aborting infinite loop!\n";
    }
    #
    # Return a new set of *marked* edges.
    #
    my @newedges = ();
    foreach my $edge (keys(%edges)) {
	next
	    if (!$edges{$edge});
	
	my ($a, $b) = split(":", $edge);
	push(@newedges, [$a, $b]);
    }
    return @newedges;
}

#
# Toggle backtrace on warning.
#
sub BackTraceOnWarning($)
{
    my ($enable) = @_;

    if ($enable) {
	$SIG{__WARN__} = sub { Carp::cluck(@_); };
	$SIG{__DIE__}  = sub { Carp::confess(@_) };
    }
    else {
	$SIG{__WARN__} = 'DEFAULT';
	$SIG{__DIE__}  = 'DEFAULT';
    }
}

#
# Convert to an encrypted hash.
#
sub PassWordHash($)
{
    my ($password) = @_;
    # Leave these here cause of SELFLOADER_DATA;
    my $MAINSITE   = 0;
    my $ELABINELAB = 0;
    my $salt;
    require libtestbed;

    if ($MAINSITE || $ELABINELAB) {
	$salt = "\$5\$" . substr(libtestbed::TBGenSecretKey(), 0, 16) . "\$";
    }
    else {
	$salt = "\$1\$" . substr(libtestbed::TBGenSecretKey(), 0, 8) . "\$";
    }
    my $passhash = crypt($password, $salt);

    return $passhash;
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
    my $ran=`/bin/dd if=/dev/urandom count=32 bs=1 2>/dev/null | /sbin/md5`;
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

#
# SSH with timeout. 
#
sub SSHwithTimeout($$$$)
{
    my ($host, $cmd, $timeout, $debug) = @_;
    my $childpid;
    my $timedout = 0;
    my $SSHTB    = "/users/mshobana/emulab-devel/build/bin/sshtb";

    $cmd = "$SSHTB -host $host $cmd";
    print "SSHwithTimeout($timeout): $cmd\n"
	if ($debug);

    if ($timeout) {
	$childpid = fork();

	if ($childpid) {
	    local $SIG{ALRM} = sub { kill("TERM", $childpid); $timedout = 1; };
	    alarm $timeout;
	    waitpid($childpid, 0);
	    my $exitstatus = $?;
	    alarm 0;

	    if ($timedout) {
		print STDERR "*** ssh timed out.\n";
		return -1;
	    }
	    return $exitstatus;
	}
	exec($cmd);
	die("Could not exec '$cmd'");
    }
    else {
	return system($cmd);
    }
}

sub GenHash()
{
    my $hash =`/bin/dd if=/dev/urandom count=128 bs=1 2> /dev/null | /sbin/md5`;
    return undef
	if ($?);
    chomp($hash);
    return $hash;
}

# Convert date to GMT
sub TBDateStringGMT($)
{
    my ($date) = @_;

    return ""
	if (!defined($date) || "$date" eq "");

    if ($date !~ /^\d+$/) {
	$date = str2time($date);
    }
    return POSIX::strftime("20%y-%m-%dT%H:%M:%SZ", gmtime($date));
}
# Convert date to Local
sub TBDateStringLocal($)
{
    my ($date) = @_;

    return ""
	if (!defined($date) || "$date" eq "");

    if ($date !~ /^\d+$/) {
	$date = str2time($date);
    }
    return POSIX::strftime("20%y-%m-%d %H:%M:%S", localtime($date));
}
# Convert date to readable UTC
sub TBDateStringUTC($)
{
    my ($date) = @_;

    return ""
	if (!defined($date) || "$date" eq "");

    if ($date !~ /^\d+$/) {
	$date = str2time($date);
    }
    return POSIX::strftime("20%y-%m-%d %H:%M UTC", gmtime($date));
}

sub isMounted($)
{
    my ($dir) = @_;
    my $rval  = 0;
    my $MOUNT   = "/sbin/mount";
    my $WITHAMD = 1;
    my $AMDROOT = "/.amd_mnt/ops";

    if ($OPSVM_ENABLE && $WITHZFS) {
	return 0
	    if (! -e $dir);
	return 1;
    }
    
    if ($WITHAMD) {
	$dir = "${AMDROOT}${dir}";
    }

    #
    # Grab the output of the mount command and parse.
    #
    if (! open(MOUNT, "$MOUNT|")) {
	print "Cannot run mount command\n";
	return 0;
    }
    while (<MOUNT>) {
	if ($_ =~ /^([-\w\.\/:\(\)]+) on ([-\w\.\/]+) \((.*)\)$/) {
	    # Search for nfs string in the option list.
	    # N.B. there may be a space after the comma in the list
	    foreach my $opt (split(/, ?/, $3)) {
		if ($opt eq "nfs" && $2 eq $dir) {
		    $rval = 1;
		}
	    }
	}
    }
    close(MOUNT);
    return $rval;
}

sub waitForMount($;$)
{
    my ($dir, $delay) = @_;
    $delay = 10 if (!defined($delay));

    for (my $i = 0; $i < $delay; $i++) {
	if (isMounted($dir)) {
	    return 0;
	}
	sleep(1);
	system("/bin/ls $dir >/dev/null 2>&1");
    }
    return -1;
}

#
# Run pw/chpass, checking for a locked passwd/group file. The pw routines
# exit with non specific error code 1 for everything, so there is no way
# to tell that its a busy file except by looking at the error message. Then
# wait for a bit and try again. Silly.
#
sub runBusyLoop($)
{
    my $command   = shift;
    my $maxtries  = 10;

    while ($maxtries--) {
	my $output    = "";
    
	#
	# This open implicitly forks a child, which goes on to execute the
	# command. The parent is going to sit in this loop and capture the
	# output of the child. We do this so that we have better control
	# over the descriptors.
	#
	my $pid = open(PIPE, "-|");
	if (!defined($pid)) {
	    print STDERR "runBusyLoop; popen failed!\n";
	    return -1;
	}
	if ($pid) {
	    while (<PIPE>) {
		$output .= $_;
	    }
	    close(PIPE);
	    print $output;
	    return 0
		if (!$? || $output !~ /(group|db) file is busy/m);
	    print "runBusyLoop; waiting a few seconds before trying again\n";
	    sleep(3);
	}
	else {
	    open(STDERR, ">&STDOUT");
	    exec($command);
	}
    }
    return -1;
}

#
# A couple of helpers to map agent strings to their numeric values.
# Making these numeric was my really dumb idea about 15 years ago.
#
sub MapEventType($)
{
    my ($arg) = @_;
    return undef
	if ($arg !~ /^[-\w]+$/);
    my $query_result =
	DBQueryWarn("select idx from event_eventtypes where type='$arg'");
    return undef
	if (!$query_result || !$query_result->numrows);
    my ($idx) = $query_result->fetchrow_array();
    return $idx;
}
sub MapEventObjectType($)
{
    my ($arg) = @_;
    return undef
	if ($arg !~ /^[-\w]+$/);
    my $query_result =
	DBQueryWarn("select idx from event_objecttypes where type='$arg'");
    return undef
	if (!$query_result || !$query_result->numrows);
    my ($idx) = $query_result->fetchrow_array();
    return $idx;
}
sub MapEventTriggerType($)
{
    my ($arg) = @_;
    return undef
	if ($arg !~ /^[-\w]+$/);
    my $query_result =
	DBQueryWarn("select idx from event_triggertypes where type='$arg'");
    return undef
	if (!$query_result || !$query_result->numrows);
    my ($idx) = $query_result->fetchrow_array();
    return $idx;
}

sub ValidUUID($)
{
    my ($uuid) = @_;
    if ($uuid =~ /^\w+\-\w+\-\w+\-\w+\-\w+$/) {
	return 1;
    }
    return 0;
}

sub ReadFile($)
{
    my ($filename) = @_;
    my $contents   = "";
    
    open(L, $filename)
	or return undef;

    while (<L>) {
	$contents .= $_;
    }
    close(L);
    return $contents;
}

#
# Use chflags on certain directories to prevent users from deleting things.
# Just a bandaid on the real problem.
#
sub SetNoDelete($)
{
    my ($filename) = @_;
    my $useflags   = 0;

    #
    # We use flags to prevent deletion of certain dirs, on FreeBSD 10
    # or greater.  Note that when OPSVM_ENABLE=1, the file systems are
    # actually on boss, not on ops, so have to this here on boss instead.
    #
    if ($OPSVM_ENABLE) {
	if (`uname -r` =~ /^(\d+)\.(\d+)/) {
	    if ($1 >= 10) {
		$useflags = 1 unless ($DISABLEFLAGS);
	    }
	}
    }
    return 0
	if (!$useflags);

    system("$CHFLAGS sunlink $filename");
    return ($? ? -1 : 0);
}
sub ClearNoDelete($)
{
    my ($filename) = @_;
    my $useflags   = 0;

    return 0
	if (! -e $filename);

    #
    # We use flags to prevent deletion of certain dirs, on FreeBSD 10
    # or greater.  Note that when OPSVM_ENABLE=1, the file systems are
    # actually on boss, not on ops, so have to this here on boss instead.
    #
    if ($OPSVM_ENABLE) {
	if (`uname -r` =~ /^(\d+)\.(\d+)/) {
	    if ($1 >= 10) {
		$useflags = 1 unless ($DISABLEFLAGS);
	    }
	}
    }
    return 0
	if (!$useflags);

    # Do a recursive change here since we tend to do deletions on the
    # top level directories.
    system("$CHFLAGS -R nosunlink $filename");
    return ($? ? -1 : 0);
}

sub escapeshellarg($)
{
    my ($str)  = @_;
    my @chars  = split('', $str);
    my $result = "";

    foreach my $ch (@chars) {
        if ($ch eq '\'') {
            $result = $result . "\'\\\'";
	}
	$result = $result . "$ch";
    }
    return "'$result'";
}

#
# Is an IP routable?
#
sub isRoutable($)
{
    my ($IP)  = @_;
    my $IPREGEX = '^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$';
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

# _Always_ make sure that this 1 is at the end of the file...
1;
