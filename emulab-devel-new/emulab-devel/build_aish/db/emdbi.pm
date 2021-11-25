#!/usr/bin/perl -w
#
# Copyright (c) 2008-2019, 2021 University of Utah and the Flux Group.
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
package emdbi;
use strict;
use File::Basename;
use English;
use Carp;
use Exporter;
use Data::Dumper;
use Fcntl;
use vars qw(@ISA @EXPORT);
@ISA = "Exporter";

# Configure variables
my $TB		= "/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish";
my $SCRIPTNAME  = "Unknown";
my $TBOPS       = "testbed-ops\@ops.cloudlab.umass.edu";
my $USEDBI	= 1;
my $MAINSITE    = 0;

# Untainted scriptname for below.
if ($PROGRAM_NAME =~ /^([-\w\.\/]+)$/) {
    $SCRIPTNAME = basename($1);
}
else {
    $SCRIPTNAME = "Tainted";
}

#############################################################################
#
# We are going to wrap the DB handle in a wrapper object so that we
# can attach the current process ID to it. This is needed so that the
# child process after a fork() 1) set's InactiveDestroy to avoid
# sending a disconnect message since it will also close the parent's
# database handle 2) reconnects since two separate processes should not
# share the same handle.  (1) is handled via overridding the database
# handle DESTROY method, (2) is handled in the DBQueryN function.
#
package emdbi_wrapper::Mysql;
use vars '@ISA';
@ISA = ('Mysql');

sub Wrap($$$)
{
    my ($class, $dbname, $dbuser) = @_;

    require Mysql;
    $Mysql::QUIET = 1;

    my $self = {};
    bless($self, $class);

    $self->{'PID'}    = undef;
    $self->{'DBH'}    = undef;
    $self->{'DBNAME'} = $dbname;
    $self->{'DBUSER'} = $dbuser;
    return $self;
}
sub pid($)	{ return $_[0]->{'PID'}; };
sub dbh($)	{ return $_[0]->{'DBH'}; };
sub dbname($)	{ return $_[0]->{'DBNAME'}; };
sub dbuser($)	{ return $_[0]->{'DBUSER'}; };

# Connect to the database.
sub Connect($)
{
    my ($self) = @_;

    return 0
        if (defined($self->{'DBH'}));

    my $dbh = Mysql->connect("localhost",
			     $self->dbname(), $self->dbuser(), "none");
    return -1
	if (!defined($dbh));

    $dbh->{'dbh'}->{'PrintError'} = 0;
    $self->{'PID'} = $$;
    $self->{'DBH'} = $dbh;
    return 0;
}

#
# Check for existence of DB
#
sub DBExists($$)
{
    my ($class, $dbname) = @_;
    
    require Mysql;
    $Mysql::QUIET = 1;
    my $dbh = Mysql->connect("localhost");
    return undef
	if (!defined($dbh));

    my @dbs = $dbh->listdbs();
    return 1
	if (grep {$_ eq $dbname} @dbs);
    return 0;
}

#
# Need to wrap the return value. See below.
#
sub query($$)
{
    my ($self, $query) = @_;
    my $result = $self->dbh->query($query);
    return undef
	if (!defined($result));

    # See below.
    bless($result, "emdbi_wrapper::Mysql::Statement");
    return $result;
}

sub DESTROY
{
    my ($self) = @_;
    # XXX Seems like a problem if parent gets here first.
    if (defined($self->pid()) && $self->pid() != $$) {
	$self->dbh()->setInactiveDestroy(1);
    }
    if (defined($self->dbh())) {
	$self->dbh()->SUPER::DESTROY()
	    if $self->dbh()->can("SUPER::DESTROY");
    }
}

#############################################################################
# Trivial wrapper for the Mysql statement so that we can add a method.
#
package emdbi_wrapper::Mysql::Statement;
use vars '@ISA';
@ISA = ('Mysql::Statement');

# Natively supported, so nothing to worry about.
sub WrapForSeek($)	{ return $_[0]; }

#############################################################################
#
# We are making the transition to DBI so we can stop using the ancient
# and unmaintained Mysql module.
#
package emdbi_wrapper::DBI;
use vars '@ISA';
@ISA = ('DBI::db');
use Data::Dumper;

sub Wrap($$$)
{
    my ($class, $dbname, $dbuser) = @_;

    require DBI;

    my $self = {};
    bless($self, $class);

    $self->{'PID'}    = undef;
    $self->{'DBH'}    = undef;
    $self->{'DBNAME'} = $dbname;
    $self->{'DBUSER'} = $dbuser;
    return $self;
}
sub pid($)	{ return $_[0]->{'PID'}; };
sub dbh($)	{ return $_[0]->{'DBH'}; };
sub dbname($)	{ return $_[0]->{'DBNAME'}; };
sub dbuser($)	{ return $_[0]->{'DBUSER'}; };

sub Connect($)
{
    my ($self) = @_;
    my $dbname = $self->dbname();
    my $dbuser = $self->dbuser();

    return 0
        if (defined($self->{'DBH'}));

    my $dbh = DBI->connect("DBI:mysql:database=$dbname;host=localhost",
			   $dbuser, "none",
			   {'PrintError' => 0});
    return -1
	if (!defined($dbh));

    $self->{'PID'} = $$;
    $self->{'DBH'} = $dbh;
    return 0;
}

#
# Check for existence of DB
#
sub DBExists($$)
{
    my ($class, $dbname) = @_;
    
    require DBI;

    my @dbs = DBI->data_sources("mysql");
    return 1
	if (grep {$_ eq "DBI:mysql:$dbname"} @dbs);
    return 0;
}

#
# Wrap query for proper DBI syntax.
#
sub query($$)
{
    my ($self, $query) = @_;

    my $dbh = $self->dbh();;
    if (!defined($dbh)) {
	print STDERR Carp::longmess();
    }
    my $sth = $dbh->prepare($query);
    return undef
	if (!$sth);

    my $query_result = $sth->execute();
    return undef
	if (!$query_result);

    # See below; we add a couple of extra routines.
    bless($sth, "emdbi_wrapper::DBI::st");
    return $sth;
}

sub DESTROY
{
    my ($self) = @_;
    # XXX Seems like a problem if parent gets here first.
    if (defined($self->pid()) && $self->pid() != $$) {
	$self->dbh()->{'InactiveDestroy'} = 1;
    }
    if (defined($self->dbh())) {
	$self->dbh()->SUPER::DESTROY()
	    if $self->dbh()->can("SUPER::DESTROY");
    }
}

#############################################################################
# Trivial wrapper for the DBI statement class to avoid a zillion silly
# changes to the rest of the code. These were defined in the Mysql
# wrapper we used to use. Pretty simple stuff, no big deal.
#
package emdbi_wrapper::DBI::st;
use vars '@ISA';
@ISA = ('DBI::st');

sub numrows($)		{ return $_[0]->rows(); };
sub num_rows($)		{ return $_[0]->rows(); };
sub affectedrows($)	{ return $_[0]->rows(); };
sub insertid($)		{ return $_[0]->{'mysql_insertid'}; };
sub fetchrow($)
{
    my ($self) = @_;
    my @row    = $self->fetchrow_array();
    return (@row ? (wantarray ? @row : $row[0]) : ());
}
sub fetchhash($)
{
    my ($self) = @_;
    my $ref    = $self->fetchrow_hashref();
    return ($ref ? %$ref : ());
}
sub as_string($)
{
    my ($self) = @_;
    $self->dump_results();
}

# Not supported so generate an error.
sub dataseek($$)
{
    DBWarn("Attempt to 'seek' not supported. Better fix it!");
}

# This is how we do it. See below.
sub WrapForSeek($)	{ return emdbi_wrapper::DBI::WrapForSeek->Wrap($_[0]); }

#############################################################################
# Another wrapper. DBI does not implement "seek" or "rewind". The only way
# to do this is suck all the data out and save it. We do not want to do this
# for every query though, so anyplace we want to seek around, wrap things
# up with this, and then use it like a normal query result. 
#
package emdbi_wrapper::DBI::WrapForSeek;

use Data::Dumper;

sub Wrap($$)
{
    my ($class, $sth) = @_;
    my @data  = ();
    my @names = ();

    #
    # This tells us the original select column ordering.
    #
    my $names = $sth->{'NAME'};
    my $numFields = $sth->{'NUM_OF_FIELDS'};
    for (my $i = 0;  $i < $numFields;  $i++) {
	push(@names, $$names[$i]);
    }

    #
    # Grab all the rows. 90 percent of queries request rows as
    # arrays, so lets do that. We can construct a hash using the
    # column names we grabbed above.
    #
    while (my $rowref = $sth->fetchrow_arrayref()) {
	#
	# This looks weird and pointless, but there is some funky
	# memory stuff going in underneath; if we do not make a copy
	# explicitly, each successive row overwrites the previous row.
	# Not very perl like.
	#
	my @row = @$rowref;
	
	push(@data, \@row);
    }

    my $self = {};
    $self->{'STH'}       = $sth;
    $self->{'ROWS'}      = $sth->rows();
    $self->{'COLNAMES'}  = \@names;
    $self->{'COLCOUNT'}  = scalar(@names);
    $self->{'DATA'}      = \@data;
    $self->{'IDX'}       = 0;

    bless($self, $class);
    return $self;
}
sub sth($)		{ return $_[0]->{'STH'}; };
sub rows($)		{ return $_[0]->{'ROWS'}; };
sub idx($)		{ return $_[0]->{'IDX'}; };
sub incridx($)		{ return $_[0]->{'IDX'}++; };
sub data($)		{ return $_[0]->{'DATA'}; };
sub colnames($)		{ return $_[0]->{'COLNAMES'}; };
sub colcount($)		{ return $_[0]->{'COLCOUNT'}; };
sub numrows($)		{ return $_[0]->{'ROWS'}; };
sub num_rows($)		{ return $_[0]->{'ROWS'}; };
sub affectedrows($)	{ return $_[0]->{'ROWS'}; };
sub insertid($)		{ return $_[0]->sth()->{'mysql_insertid'}; };
sub dataseek($$)	{ $_[0]->{'IDX'} = $_[1]; };

sub fetchrow_arrayref($)
{
    my ($self) = @_;
    my $data   = $self->data();
    my $idx    = $self->idx();

    return undef
	if ($idx >= $self->rows());

    $self->incridx();
    return $data->[$idx];
}

sub fetchrow_array($)
{
    my ($self) = @_;
    my $ref    = $self->fetchrow_arrayref();

    return ()
	if (!defined($ref));

    return @{ $ref };
}

sub fetchrow_hashref($)
{
    my ($self) = @_;
    my $ref    = $self->fetchrow_arrayref();

    return undef
	if (!defined($ref));

    #
    # Construct a hash using the column names
    #
    my %hash  = ();
    my $count = $self->colcount();
    for (my $i = 0; $i < $count; $i++) {
	$hash{$self->colnames()->[$i]} = $ref->[$i];
    }
    return \%hash;
}

sub fetchrow($)
{
    my ($self) = @_;
    my @row    = $self->fetchrow_array();
    return (@row ? (wantarray ? @row : $row[0]) : ());
}
sub fetchhash($)
{
    my ($self) = @_;
    my $ref    = $self->fetchrow_hashref();
    return ($ref ? %$ref : ());
}

#############################################################################
# Back to the main package.
#
package emdbi;

#
# Set up for querying the database. Note that fork causes a reconnect
# to the DB in the child.
#
my @DB = ();

use vars qw($DBQUERY_MAXTRIES $DBCONN_MAXTRIES $DBErrorString $DBCONN_USEDBI
	    $DBCONN_EXITONERR $DBQUERY_RECONNECT $DBQUERY_DEBUG);
$DBQUERY_MAXTRIES  = 5;  # Retry forever if zero
$DBQUERY_RECONNECT = 1;
$DBCONN_USEDBI     = $USEDBI;
$DBCONN_MAXTRIES   = 5;  # Retry forever if zero
$DBCONN_EXITONERR  = 1;
$DBQUERY_DEBUG     = 0;
$DBErrorString     = "";
@EXPORT            = qw($DBQUERY_MAXTRIES $DBQUERY_RECONNECT $DBErrorString
			$DBCONN_EXITONERR $DBCONN_MAXTRIES $DBQUERY_DEBUG);

my $queryCount = 0;

#
# Does DB exist yet.
#
sub DBExists($)
{
    my ($dbname) = @_;

    if ($DBCONN_USEDBI) {
	return emdbi_wrapper::DBI->DBExists($dbname);
    }
    else {
	return emdbi_wrapper::Mysql->DBExists($dbname);
    }
}

sub TBDBConnect($$)
{
    my ($dbnum, $dbname) = @_;
    my $maxtries = $DBCONN_MAXTRIES || 999999;

    if (!defined($dbname)) {
	    print STDERR "What DBNAME should I use?\n";
	    return -1
		if (! $DBCONN_EXITONERR);
	    exit(-1);
    }
    
    #
    # Do nothing if this DB handle is already connected to DB.
    #
    if (defined($DB[$dbnum])) {
	my $dbhw = $DB[$dbnum];
	
	return 0
	    if ($dbhw->dbname() eq $dbname);
	
	print STDERR "DBnum $dbnum already connected to another DB: ".
	    $dbhw->dbname() . "!\n";
	return -1
	    if (! $DBCONN_EXITONERR);
	exit(-1);
    }

    #
    # Construct a 'username' from the name of this script and the user who
    # ran it. This is for accounting purposes.
    #
    my $name = getpwuid($UID);
    if (!$name) {
	$name = "uid$UID";
    }
    my $dbuser = "$SCRIPTNAME:$name:$PID";

    if ($DBQUERY_DEBUG) {
	print STDERR "DBConnect:$dbnum $dbname $$\n";
    }
    my $dbhw;
    if ($DBCONN_USEDBI) {
	$dbhw = emdbi_wrapper::DBI->Wrap($dbname, $dbuser);
    }
    else {
	$dbhw = emdbi_wrapper::Mysql->Wrap($dbname, $dbuser);
    }
    if (!defined($dbhw)) {
	print STDERR "Cannot create database connection wrapper for $dbname\n";
	return -1
	    if (! $DBCONN_EXITONERR);
	exit(-1);
    }
    $DB[$dbnum] = $dbhw;

    while ($maxtries) {
	last
	    if ($dbhw->Connect() == 0);

	$maxtries--;
	if ($maxtries) {
	    print STDERR "Cannot connect to DB $dbname; ".
		"trying again in a few seconds!\n";
	    sleep(10);
	}
    }
    if (!$maxtries) {
	print STDERR "Cannot connect to DB $dbname after a long time!\n";
	return -1
	    if (! $DBCONN_EXITONERR);
	exit(-1);
    }
    if ($DBQUERY_DEBUG) {
	print "DBConnect:$dbnum: Connected to DB $dbname in process $PID\n";
    }
    return 0;
}

# New version.
sub TBDBReconnect($)
{
    my ($retry) = @_;
    my ($exitonerr);
    
    if ($retry) {
	$exitonerr = $DBCONN_EXITONERR;
	$DBCONN_EXITONERR = 0;

	#
	# Once we have started running, we we do not want to quit early
	# if mysqld fails. We want to wait until it comes back and the
	# caller can continue. Typically, this will not be long cause the
	# watchdog is going to get it going in a couple of minutes.
	#
	$DBCONN_MAXTRIES  = 10000;
	$DBQUERY_MAXTRIES = 10000;
    }

    for (my $i = 0; $i < @DB; $i++) {
	next
	    if (!defined($DB[$i]));

	my $dbname = $DB[$i]->dbname();
	
	undef($DB[$i]);
	return -1
	    if (TBDBConnect($i, $dbname) != 0);
    }

    if ($retry) {
	$DBCONN_EXITONERR = $exitonerr;
    }
    return 0;
}

# To avoid keeping a mysql connection around.
sub TBDBDisconnect()
{
    for (my $i = 0; $i < @DB; $i++) {
	undef($DB[$i]);
    }
}

# Create a new DB handle and return the handle number
sub NewTBDBHandle($)
{
    my ($dbname) = @_;
    
    my $dbnum = @DB;
    # Avoid using the initial one here.
    $dbnum++
	if (!$dbnum);
    
    TBDBConnect($dbnum, $dbname);
    return $dbnum;
}

sub LockDebugWrite($$)
{
    my ($dbw, $message) = @_;
    my $now     = time();
    my $dbname  = $dbw->dbname();
    my $logname = "/usr/testbed/log/mysqllockdebug";
    my $string  = "$dbname,$PID,$now: $message\n";

    if (sysopen(LOG, $logname, O_CREAT | O_WRONLY | O_APPEND, 0666)) {
	syswrite(LOG, $string);
	close(LOG);
    }
    else {
	print "LockDebug: Could not open file\n";
    }
}
sub LockDebug($$)
{
    my ($dbw, $query) = @_;

    # Disable, the race is dead! 
    return 0
	if (1);

    return 0
	if (! ($MAINSITE && $query =~ /lock\s+tables/i));

    LockDebugWrite($dbw, $query);

    return 0
	if ($query =~ /unlock\s+tables/i);
    return 1;
}

#
# Issue a DB query. Argument is a string. Returns the actual query object, so
# it is up to the caller to test it. I would not for one moment view this
# as encapsulation of the DB interface. I'm just tired of typing the same
# silly stuff over and over.
#
# usage: DBQuery(char *str)
#        returns the query object result.
#
# Sets $DBErrorString is case of error; saving the original query string and
# the error string from the DB module. Use DBFatal (below) to print/email
# that string, and then exit.
#
sub DBQueryN($$)
{
    my($dbnum, $query)   = @_;
    my $maxtries = $DBQUERY_MAXTRIES || 999999;
    my $result;

    # Update query count total for debugging purposes
    $queryCount += 1;

    if ($DBQUERY_DEBUG) {
	print STDERR "Query:$dbnum '$query'\n";
    }

    # Mostly for ProtoGeni;
    if (!defined($dbnum)) {
	print STDERR "DB connection not setup:\n";
	print STDERR "Query: '$query'\n";
	return undef;
    }
    my $dbw = $DB[$dbnum];
    # Reconnect to mysqld in child of fork.
    if (defined($dbw->pid()) && $dbw->pid() != $PID) {
	#print "DBQueryN:$dbnum Detected a fork in $PID. Reconnecting\n";
	if (TBDBReconnect(1) != 0) {
	    $DBErrorString =
		"  Query: $query\n".
		"  Error: Could not reconnect to mysqld in child of fork";
	    return undef;
	}
	# New wrapper
	$dbw = $DB[$dbnum];
    }
    # Watch for a dead connection before we even try. We can do this with
    # the DBI wrapper.
    if (defined($dbw->dbh()) && $DBCONN_USEDBI && !$dbw->dbh()->ping()) {
	#print "DBQueryN:$dbnum ping failed in $PID. Reconnecting\n";
	if (TBDBReconnect(1) != 0) {
	    $DBErrorString =
		"  Query: $query\n".
		"  Error: Could not reconnect to mysqld";
	    return undef;
	}
	# New wrapper
	$dbw = $DB[$dbnum];
    }

    my $lockstatement = LockDebug($dbw, $query);

    while ($maxtries) {
	# Get this each time through the loop since we try reconnect below.
	$dbw    = $DB[$dbnum];
	$result = $dbw->query($query);

	if (! defined($result)) {
	    my $db  = $dbw->dbh();
	    my $err = $db->err;

	    $DBErrorString =
		"  Query: $query\n".
		"  Error: " . $db->errstr . " ($err)";
	}
	my $db = $dbw->dbh();
	
	if (defined($result) ||
	    ($db->err != 2006 && $db->err != 1053 && $db->err != 2013 &&
	     $db->err != 1046 && $db->err != 1317 && $db->err != 1213)) {
	    last;
	}

	#
	# Rare dealock error.
	#
	if ($db->err == 2013) {
	    DBWarn($db->errstr, 0);
	    $maxtries--;
	    sleep(10);
	    next;
	}

	#
	# If we lose the connection to mysqld; lets try to reconnect. 
	#
	if ($db->err == 2006 || $db->err == 2013 ||
	    ($DBCONN_USEDBI && !$dbw->dbh()->ping())) {
	    # This is just for the mysqld watchdog daemon.
	    return undef
		if (! $DBQUERY_RECONNECT);

	    if (TBDBReconnect(1) != 0) {
		$DBErrorString =
		    "  Query: $query\n".
		    "  Error: Could not reconnect to mysqld";
		DBWarn("mysqld went away in process $PID. Cannot reconnect", 0);
		return undef;
	    }
	    # New wrapper
	    $dbw = $DB[$dbnum];
	    next;
	}
	$maxtries--;
	DBWarn("mysqld went away in process $PID. $maxtries tries left", 1);
	sleep(10);
    }
    if (!$maxtries) {
	DBWarn("mysqld went away in process $PID. No tries left", 0);
    }
    if ($lockstatement) {
	LockDebugWrite($dbw, "lock tables returned");
    }
    return $result;
}
sub DBQuery($) {return DBQueryN(0,$_[0]);}

#
# Same as above, but die on error.
#
sub DBQueryFatalN($$)
{
    my($dbnum, $query) = @_;
    my($result);

    $result = DBQueryN($dbnum, $query);

    if (! $result) {
	DBFatal("DB Query failed");
    }
    return $result;
}
sub DBQueryFatal($) {return DBQueryFatalN(0,$_[0]);}

#
# Like DBQueryFatal but also fail if the query didn't return any
# results and returns the result as an array in list context or the
# first column of the result is scalar content.
#
sub DBQuerySingleFatalN($$)
{
    my ($dbnum, $query) = @_;
    my $query_result = DBQueryFatalN($dbnum, $query);
    DBFatal("DB Query \"$query\" didn't return any results") 
	unless $query_result->numrows > 0;
    DBFatal("DB Query \"$query\" returned more than one row")
	unless $query_result->numrows == 1;
    my @row = $query_result->fetchrow_array();
    return wantarray ? @row : $row[0];
}
sub DBQuerySingleFatal($) {return DBQuerySingleFatalN(0,$_[0]);}

#
# Same as above, but just send email on error. This info is useful
# to the TB system, but the caller has to retain control.
#
sub DBQueryWarnN($$)
{
    my($dbnum, $query) = @_;
    my($result);

    $result = DBQueryN($dbnum, $query);

    if (! $result) {
	DBWarn("DB Query failed");
    }
    return $result;
}
sub DBQueryWarn($) {return DBQueryWarnN(0,$_[0]);}

#
# Helper functions.
#
sub emdbi_die($)	{ die($_[0]); }
sub emdbi_warn($)	{ warn($_[0]); }

#
# Warn and send email after a failed DB query. First argument is the error
# message to display. The contents of $DBErrorString is also printed.
#
# usage: DBWarn(char *message)
#
sub DBWarn($;$)
{
    my($message, $nomail) = @_;
    
    DBError(\&emdbi_warn, $message, $nomail);
}

#
# Same as above, but die after the warning.
#
# usage: DBFatal(char *message);
#
sub DBFatal($;$)
{
    my ($message,$nomail) = $_[0];
    
    DBError(\&emdbi_die, $message, $nomail);
}

#
# DBError, common parts of DBWarn and DBFatal
#
# usage: DBError(log function, message, nomail)
#
sub DBError($$;$) 
{
    my($f, $message, $nomail) = @_;
    
    if (! defined($nomail)) {
	if (open(MAIL, "| /usr/sbin/sendmail -i -t")) {
	    print MAIL "To: $TBOPS\n";
	    print MAIL "Subject: DBError\n";
	    print MAIL "\n";
	    print MAIL "In $SCRIPTNAME\n\n";
	    print MAIL "$message\n\n";
	    print MAIL "$DBErrorString\n\n";
	    print MAIL Carp::longmess();
	    print MAIL "\n";
	    close(MAIL);
	}
    }

    $f->("$message:\n$DBErrorString\n");
}

#
# Quote a string for DB insertion.
#
# usage: char *DBQuoteSpecial(char *string);
#
sub DBQuoteSpecial($)
{
    my ($string) = @_;
    my $dbw = $DB[0];

    return $dbw->dbh()->quote($string);
}

sub DBQuoteSpecialN($$)
{
    my ($dbnum, $string) = @_;
    my $dbw = $DB[$dbnum];

    return $dbw->dbh()->quote($string);
}

#
# Get the Error From the Last Database query
#
sub DBErrN($)
{
    return $DB[$_[0]]->dbh()->err;
}
sub DBErr()
{
    return $DB[0]->dbh()->err;
}

#
# Some utility routines for doing migration (DB upgrades).
#
sub DBTableExistsN($$)
{
    my($dbnum, $table) = @_;

    my $result =
	DBQueryFatalN($dbnum, "show tables like '$table'");

    return $result->numrows;
}
sub DBTableExists($) { return DBTableExistsN(0,$_[0]); }

sub DBSlotExistsN($$$)
{
    my($dbnum, $table, $slot) = @_;

    my $result =
	DBQueryFatalN($dbnum, "show columns from `$table` like '$slot'");

    return $result->numrows;
}
sub DBSlotExists($$) { return DBSlotExistsN(0,$_[0],$_[1]); }

sub DBSlotTypeN($$$)
{
    my($dbnum, $table, $slot) = @_;

    my $result =
	DBQueryFatalN($dbnum, "show columns from `$table` like '$slot'");

    return undef
	if (! $result->numrows);
    my $row = $result->fetchrow_hashref();
    return $row->{'Type'};
}
sub DBSlotType($$) { return DBSlotTypeN(0,$_[0],$_[1]); }

sub DBKeyExistsN($$$)
{
    my($dbnum, $table, $keyname) = @_;

    my $result =
	DBQueryFatalN($dbnum, "show index from `$table`");

    while (my (undef,undef,$kname,undef,$colname) = $result->fetchrow_array()){
	return 1
	    if ($kname eq $keyname);
    }
    return 0;
}
sub DBKeyExists($$) { return DBKeyExistsN(0,$_[0],$_[1]); }

sub DBHandleN($)
{
    my ($dbnum) = @_;
    
    my $dbw = $DB[$dbnum];
    
    my $db  = $dbw->dbh();
    

    return $db;
}
sub DBHandle()	    { return DBHandleN(0); }

END {
    # Call it here otherwise may get:
    #   (in cleanup) Can't call method "FETCH" on an undefined value at 
    #   /usr/local/lib/perl5/site_perl/5.8.8/mach/Mysql.pm line 91 during 
    #   global destruction.
    # where line 91 is:
    #  	my $oldvalue = $self->{'dbh'}->{'InactiveDestroy'};
    # which is in setInactiveDestroy() which get called in libdb.pm in:
    #   if ($self->db_pid() != $$) {
    #       $self->setInactiveDestroy(1);
    #   }
    # which is in TestbedDBHandle::DESTROY (still in libdb.pm even
    # though it is a diffrent package)
    #
    # This error is probably due to some object being destroyed too
    # soon somewhere in the DBI/DBD modules.
    TBDBDisconnect();
}

sub ClearQueryCount()
{
    $queryCount = 0;
}

sub GetQueryCount()
{
    return $queryCount;
}

# _Always_ make sure that this 1 is at the end of the file...

1;

