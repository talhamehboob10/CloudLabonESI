#!/usr/bin/perl -w
#
# Copyright (c) 2005-2011 University of Utah and the Flux Group.
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
# A library of useful DB stuff, currently just for use on ops.
#
package libtbdb;
use strict;
use Exporter;
use vars qw(@ISA @EXPORT);
@ISA = "Exporter";
@EXPORT =
    qw ( DBQuery DBQueryFatal DBQueryWarn DBWarn DBFatal
	 DBQuoteSpecial TBDBConnect TBDBDisconnect DBBinaryQuery
	 );

# Must come after package declaration!
use English;
use File::Basename;
require DBI;
use vars qw($DBQUERY_MAXTRIES $DBCONN_MAXTRIES @EXPORT_OK);

# Configure variables
my $TB		= "/users/mshobana/emulab-devel/build";
my $TBOPS       = "testbed-ops\@ops.cloudlab.umass.edu";
my $SCRIPTNAME  = "Unknown";

# Untainted scriptname for email below.
if ($PROGRAM_NAME =~ /^([-\w\.\/]+)$/) {
    $SCRIPTNAME = basename($1);
}
else {
    $SCRIPTNAME = "Tainted";
}

#
# Set up for querying the database. Note that fork causes a reconnect
# to the DB in the child.
#
my $DB;
$DBQUERY_MAXTRIES = 1;
$DBCONN_MAXTRIES  = 5;
@EXPORT_OK        = qw($DBQUERY_MAXTRIES $DBCONN_MAXTRIES);

#
# Need to remember these in case we need to reconnect.
#
my $tbdbname;
my $tbdbuser;
my $tbdbhost   = "localhost";
my $tbdbpasswd = "none";

#############################################################################
# Trivial wrapper for the DBI statement class to avoid a zillion silly
# changes to the rest of the code. These were defined in the Mysql
# wrapper we used to use. Pretty simple stuff, no big deal.
#
package libtbdb_wrapper::DBI::st;
use vars '@ISA';
@ISA = ('DBI::st');

sub dataseek($$)	{ return $_[0]->func($_[1], 'dataseek'); };
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

#############################################################################
# Back to the main package.
#
package libtbdb;

#
# Database handle passed by reference as 5th argument ($_[4])
#
sub TBDBConnect($;$$$$)
{
    my ($dbname, $dbuser, $dbpasswd, $dbhost) = @_;
    my $maxtries = $DBCONN_MAXTRIES;

    #
    # Construct a 'username' from the name of this script and the user who
    # ran it. This is for accounting purposes.
    #
    if (!defined($dbuser)) {
	my $name = getpwuid($UID);
	if (!$name) {
	    $name = "uid$UID";
	}
	$dbuser = "$SCRIPTNAME:$name:$PID";
    }
    $tbdbname   = $dbname;
    $tbdbuser   = $dbuser;
    $tbdbpasswd = $dbpasswd
	if (defined($dbpasswd));
    $tbdbhost   = $dbhost
	if (defined($dbhost));

    while ($maxtries) {
	$DB = DBI->connect("DBI:mysql:database=$tbdbname;host=$tbdbhost",
			   $tbdbuser, $tbdbpasswd,
			   {'PrintError' => 0});
	if (defined($DB)) {
	    last;
	}
	$maxtries--;
	sleep(1);
    }
    if (!defined($DB)) {
	print STDERR "Cannot connect to DB after several attempts!\n";
	# Ensure consistent error value. 
	return -1;
    }
    if (@_ == 5)  {
	$_[4]->{'tbdbname'} = $tbdbname;
	$_[4]->{'tbdbuser'} = $tbdbuser;
	$_[4]->{'tbdbpasswd'} = $tbdbpasswd;
	$_[4]->{'tbdbhost'} = $tbdbhost;
	$_[4]->{'DB'} = $DB;
    }
    return 0;
}

sub TBDBDisconnect(;$)
{
    if (defined($_[0])) {
	undef($_[0]->{'DB'});
    } else {
	undef $DB;
    }    
}
    
#
# Record last DB error string.
#
my $DBErrorString = "";

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
sub DBQuery($;$)
{
    my($query, $handle)   = @_;
    my $dbhandle;
    if (!defined($handle)) {
	$dbhandle = $DB;
    } else {
	$dbhandle = $handle->{'DB'};
    }
    my $maxtries = $DBQUERY_MAXTRIES;
    my $result;

    # Not really forever :-)
    if (!$maxtries) {
	$maxtries = 100000;
    }

    while ($maxtries) {
	my $sth = $dbhandle->prepare($query);
	if (!$sth) {
	    my $err = $dbhandle->err;

	    $DBErrorString =
		"  Query: $query\n".
		"  Error: " . $dbhandle->errstr() . " ($err)";
	    last;
	}
	my $query_result = $sth->execute();
	if (defined($query_result)) {
	    $sth->{'CompatMode'} = 1;
	    # See above; we add a couple of extra routines.
	    bless($sth, "libtbdb_wrapper::DBI::st");
	    $result = $sth;
	}
	else {
	    my $err = $dbhandle->err;

	    $DBErrorString =
		"  Query: $query\n".
		"  Error: " . $dbhandle->errstr . " ($err)";
	}
	if (defined($query_result) ||
	    ($dbhandle->err != 2006) && ($dbhandle->err != 1053) && 
            ($dbhandle->err != 2013) &&
	    ($dbhandle->err != 1046)) {
	    last;
	}

	$maxtries--;
	DBWarn("mysqld went away. $maxtries tries left", 0);
	sleep(1);
    }
    return $result;
}

#
# Same as above, but die on error.
#
sub DBQueryFatal($;$)
{
    my ($query, $handle) = @_;
    my($result);

    $result = DBQuery($query, $handle);

    if (! $result) {
	DBFatal("DB Query failed");
    }
    return $result;
}

#
# Same as above, but just send email on error. This info is useful
# to the TB system, but the caller has to retain control.
#
sub DBQueryWarn($;$)
{
    my ($query, $handle) = @_;
    my($result);

    $result = DBQuery($query, $handle);

    if (! $result) {
	DBWarn("DB Query failed");
    }
    return $result;
}

#
# Warn and send email after a failed DB query. First argument is the error
# message to display. The contents of $DBErrorString is also printed.
#
# usage: DBWarn(char *message)
#
sub DBWarn($;$)
{
    my($message, $nomail) = @_;
    my($text);

    $text = "$message - In $SCRIPTNAME\n" .
  	    "$DBErrorString\n";

    print STDERR "*** $text";

    if (! defined($nomail) && (exists($INC{'libtestbed.pm'}))) {
        libtestbed::SENDMAIL($TBOPS, "DBError - $message", $text);
    }
}

#
# Same as above, but die after the warning.
#
# usage: DBFatal(char *message);
#
sub DBFatal($)
{
    my($message) = $_[0];

    DBWarn($message);

    die("\n");
}

#
# Quote a string for DB insertion.
#
# usage: char *DBQuoteSpecial(char *string);
#
sub DBQuoteSpecial($;$)
{
    my($string, $handle) = @_;
    my $dbhandle;
    if (!defined($handle)) {
	$dbhandle = $DB;
    } else {
	$dbhandle = $handle->{'DB'};
    }
    $string = $dbhandle->quote($string);

    return $string;
}

#
# Return a (current) string suitable for DB insertion in datetime slot.
# Of course, you can use this for anything you like!
#
# usage: char *DBDateTime(int seconds-to-add);
#
sub DBDateTime(;$)
{
    my($seconds) = @_;

    if (! defined($seconds)) {
	$seconds = 0;
    }

	    return strftime("20%y-%m-%d %H:%M:%S", localtime(time() + $seconds));
}

# Binary mode for database query
#
# usage: DBBinaryQuery(dbhandle, statement, @data);
#        returns the query object result.
#
# Sets $DBErrorString is case of error; saving the original query string and
# the error string from the DB module. Use DBFatal to print/email
# that string, and then exit.
#

sub DBBinaryQuery {
   my ($handle, $statement, @data) = @_; 
   
   my $dbh = $handle->{'DB'};
   my $sth = $dbh->prepare($statement);
   if (!$sth) {
       $DBErrorString =
	   "  Query: $statement\n".
	   "  Error: " . $dbh->errstr() . " ( " . $dbh->err() . ")";
       return undef;
   }
   
   my $query_result = $sth->execute(@data);
   if (!$query_result) {
       $DBErrorString =
	   "  Query: $statement\n".
	   "  Error: " . $dbh->errstr() . " ( " . $dbh->err() . ")";
       return undef;
   }
   $sth->{'CompatMode'} = 1;
   # See above; we add a couple of extra routines.
   bless($sth, "libtbdb_wrapper::DBI::st");
   $sth;
}

# _Always_ make sure that this 1 is at the end of the file...

1;

