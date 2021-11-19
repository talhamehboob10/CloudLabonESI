#!/usr/bin/perl -w

#
# Copyright (c) 2005-2018 University of Utah and the Flux Group.
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

=head1 NAME

libtblog - Logging library for testbed

=head1 BASIC USAGE

See the REFERENCE section for detailed descriptions of any of the
functions mentioned here.

=head2 Quick Start

Every perl script that can possible report a testbed related error
should use libtblog.  This should be done in the same place that
the other testbed libraries are included:

    use lib "/test/lib";
    ...
    use libtblog;
    ...

This will activate the logging subsystem.  All output to STDOUT
and STDERR will, by default, be captured and turned into log
messages, in addition to being printed.  Handlers are also installed
for die/warn.  To turn this feature off use tblog_stop_capture(...).

If the script may be used at a top level than tblog_set_info(...)
should be used.

Than all output should use one of the tb* functions calls as follows:

    tberror("message")   # to report an error
    tbwarn("message")    # to report a warning
    tbnotice("message")  # to report important information that not
                         # really a warning.
    tbinfo("message")    # for normal log messages

    tbdie("message")     # to report an error than die using perl "die"

The tb* log functions (except for tbinfo) will automatically prefix
the message with "***" and other appropriate formatting so don't
include any.  However, multiline messages are okay.

Normal perl C<die> can and should still be used when reporting an
internal error such as calling a function incorrectly.  The message
will still be logged but it will be flagged as an internal error.

For basic usage that it.

=head2 Associating a Cause With An Error

One of the goals of this system is to be able to determine the cause
of an error.  The current causes are:

    temp - resources temp unavailable
    user - user error
    internal - software bug, should not happen
    software - software problem, like a bad image
    hardware - hardware problem
    canceled - canceled
    unknown - default

The cause for an error can be set directly when calling tberror by passing
in the "cause" parameter.  For example:

    tberror({cause => 'temp'}, "message")

Or, a default cause can be set for a script using
"tblog_set_default_cause", for example:

    tblog_set_default_cause ('temp')

The cause is only relevant for errors.  For that reason
tblog_set_default_cause will only set the default cause for errors.

When using the normal perl C<die> or C<warn> the cause is always set
to "internal", since they may come from perl itself.

=head2 Primary vs Secondary Error

A primary error is an error which directly identifies the cause of the
problem such as "not enough nodes free".  A secondary error is the
result of a primary error such as "assign failed".  Tblog uses this
information to help determine when it found the root cause.  By
default an error is neither primary or secondary.  To flag an error
as either set the "type" parameter to "primary" or "secondary"
respectfully.  For example:

  tberror({type => 'primary'}, "message");
  rberror({type => 'secondary'}, "message");

Note, multiple parameters can be specified, so that the "type"
parameter can be combined with the "cause" parameter.  For example:

  tberror({cause => 'temp', type => 'primary'}, "message");

=head2 Finding the Cause of the Error

Use tblog_find_error, or if you are sure tblog_find_error was already
called used tblog_lookup_error.

=head1 ADVANCE USAGE

=head2 Understanding How tblog_find_error Works

When something goes wrong tblog_find_error will reconstruct a trace of
what script called what.  Of all the scripts which reported errors, it
will then use the last one at the deepest level.

For example consider the following:

    e (top)
       * (a)
       e (b)
          e (1)
       * (c)
       e (d)
          E (2)
       * (e)

In this example "top" called script "a", "b", "c", "d", "e".  When it
called "b" something went wrong but it continued anyway, it than
called "d" which failed.  However script "d" also called "2" which
also failed.  Thus libtblog will report the errors coming from "2",
the fact that "e" was called after "d" is irrelevant, since it didn't
report any errors.

However, this strategy doesn't always work.  The rest of this section
will deal with the cases when it doesn't and how to help it.

=head2 Extra, and Summary Log Messages

In the case when an error message provides I<extra> information, that
the user should know about, on what just happened with a script at a
lower level, the "type" parameter should be used to set the message
type to "extra":

    tberror {type => 'extra'}, ...

A good example of using the "extra" type to good effect is in
assign_wrapper:

    fatal({type=>'extra', cause=>'user'},
          "Experiment can not be run on an empty testbed. ".
          "Please fix the experiment.");

Where C<fatal> here just calls tberror and then exists.

In the case when the error message provides a useful I<summary> of the
errors at the lower level, and should replace them, the message type
should be set to "summary":

    tberror {type => 'summary'}, ...

=head2 Using Sublevels

In some cases a script does more than one abstract thing such that
when one thing fails it will report an error than latter on report
that X failed.  Since both errors are coming from the same script
both will be reported, but in reality only the error
from the first thing should be reported.  To correct this situation
the "sublevel" parameter should be used.  This parameter tweaks the
call trace so that some errors are at a deeper level than others, even
though they are coming form the same script.  The default sublevel is
0.  Negative sublevels can be used.

For example, consider the following code:

    $res = do_something()

    tbdie "do_something failed!" unless $res;

    sub do_something() {
        ...
        tberror "foo not responding!";
        return 0;
       ...
    }

Without using sublevel the reported errors will be:

    foo not responding!
    do_something failed!

However, the second error is not needed.  To fix this, the sublevel
parameter should be added to one of the tb* calls.  This can either be
accomplished by setting the sublevel to 1 on the "foo not
responding!" error, or -1 on the "do_something failed!" error.  Since
do_something may have many errors it is often easier to set the
sublevel on the "do_something failed!" error:

    ...
    tbdie {sublevel => -1}, do_something failed!" unless $res;
    ...

=head2 Sub Processes

In some cases, such as when forking children to run in parallel,
simply using the sublevel parameter is not enough.  In this case
a new sub-process should be started with tblog_sub_process.

=head1 OTHER SCRIPTS

Currently libtblog is only usable from perl scripts running on boss.
To get errors coming form non-perl programs, or scripts running on ops,
into the system the output should be parsed for errors.  For examples
of this see F<assign_wrapper2> and F<parse-ns>.

=head1 REFERENCE

=over

=cut

package libtblog;
use Exporter;

@ISA = "Exporter";
@EXPORT = qw (tblog tberror tberr tbwarn tbwarning tbnotice tbinfo tbdebug 
	      tbdie tbreport tblog_set_info tblog_set_default_cause
	      tblog_sub_process tblog_find_error tblog_email_error
	      tblog_start_capture tblog_stop_capture
	      tblog_new_process tblog_new_child_process
	      tblog_new_session tblog_init_process tblog_exit
	      tblog_session tblog_lookup_error tblog_format_error
	      tblog_set_attempt tblog_inc_attempt tblog_get_attempt
	      tblog_set_cleanup tblog_get_cleanup
	      copy_hash
	      TBLOG_EMERG TBLOG_ALERT TBLOG_CRIT TBLOG_ERR 
	      TBLOG_WARNING TBLOG_NOTICE TBLOG_INFO TBLOG_DEBUG
	      SEV_DEBUG SEV_NOTICE SEV_WARNING SEV_SECONDARY
	      SEV_ERROR SEV_ADDITIONAL SEV_IMMEDIATE);
@EXPORT_OK = qw (dblog *SOUT *SERR);

# After package decl.
# DO NOT USE "use English" in this module
use POSIX qw(isatty setsid);
use File::Basename;
use IO::Handle;
use Text::Wrap;
use Text::Tabs;
use Carp;

use strict;

#use Data::Dumper;

#
# Testbed Support libraries
#
use libtestbed;
use emdb qw(NewTBDBHandle DBQueryN DBQueryWarnN DBQueryFatalN
	     DBQuoteSpecial $DBQUERY_MAXTRIES DBWarn DBFatal);
use libtblog_simple;

my $REAL_SCRIPTNAME = $SCRIPTNAME;
undef $SCRIPTNAME; # signal to use $ENV{TBLOG_SCRIPTNAME}

my $DB;
my $TBLOG_PID;

my $FORCED_SESSION = 0;

my $REVISION_STR = '$Revision: 2.27 $';

open SOUT ,">&=STDOUT"; # Must be "&=" not "&" to avoid creating a
                        # new low level file descriper as this
                        # interacts strangly with the fork in swapexp.
autoflush SOUT 1;

#
# Internal Utility Functions
#

sub check_env_def ( $ )
{
  croak "Environment variable \"$_[0]\" not defined" unless defined $_[0];
}

sub check_env_num ( $ )
{
    check_env_def $_[0];
    croak "Environment variable \"$_[0]\" not a positive integer" 
	unless $ENV{$_[0]} =~ /^[0-9]+$/;
}

sub check_env ()
{
    check_env_num 'TBLOG_LEVEL';
    check_env_num 'TBLOG_SESSION';
    check_env_num 'TBLOG_EXPTIDX';
    check_env_num 'TBLOG_INVOCATION';
    check_env_num 'TBLOG_PARENT_INVOCATION';
    check_env_num 'TBLOG_UID';
    check_env_num 'TBLOG_ATTEMPT';
    check_env_num 'TBLOG_CLEANUP';
    check_env_num 'TBLOG_SCRIPTNUM';
    check_env_def 'TBLOG_SCRIPTNAME';
    check_env_def 'TBLOG_BASE_SCRIPTNAME';
}

my %CAUSE_MAP = (# Don't notify testbed-ops
		 temp => 'temp', # resources temp unavailable
		 user => 'user', # user error
		 canceled => 'canceled', # canceled
		 # Notify testbed-ops
		 internal => 'internal', # software bug, should not happen
		 software => 'software', # software problem, like a bad image
		 hardware => 'hardware', # hardware problem
		 unknown => '');

sub normalize_cause ( $ ) {
    my $cause = $CAUSE_MAP{$_[0]};
    croak "Unknown cause \"$cause\"" unless defined $cause;
    return $cause;
}

sub indent ( $$ ) {
    my ($text, $prefix) = @_;
    $text =~ s/\n$//;
    my $res = '';
    foreach (split /\n/, $text) {
	$res .= $prefix;
	$res .= $_;
	$res .= "\n";
    }
    return $res;
}

sub add_prefix ( $$ ) {
    my ($prefix, $mesg) = @_;
    if ($mesg =~ /\n./) {
	return "$prefix:\n$mesg";
    } else {
	return "$prefix: $mesg";
    }
}

#
#
#


#
# Standard DBQuery functions from dblog but use private database handle
#
sub DBQuery ( $ )      {return DBQueryN($DB, $_[0]);}
sub DBQueryFatal ( $ ) {return DBQueryFatalN($DB, $_[0]);}
sub DBQueryWarn ( $ )  {return DBQueryWarnN($DB, $_[0]);}

#
# Like DBQueryFatal but also fail if the query didn't return any results
#
sub DBQuerySingleFatal ( $ )
{
    my ($query) = @_;
    my $query_result = DBQueryFatalN($DB, $query);
    DBFatal("DB Query \"$query\" didn't return any results") 
	unless $query_result->numrows > 0;
    my @row = $query_result->fetchrow_array();
    return $row[0];
}

#
# Convert the script name to a number
#
sub script_name_to_num( $ ) {
    my ($scriptname) = @_;
    my $scriptnum;

    my $query_result = DBQueryFatal
	sprintf("select script from scripts where script_name=%s",
		DBQuoteSpecial $scriptname);
    if ($query_result->num_rows > 0) {
	$scriptnum = ($query_result->fetchrow_array())[0];
    } else {
	DBQueryFatal 
	    sprintf("insert into scripts (script_name) values (%s)",
		    DBQuoteSpecial $scriptname);
	$scriptnum = DBQuerySingleFatal 'select LAST_INSERT_ID()';
    }
    return $scriptnum;
}

#
# Forward Decals
#

sub dblog ( $$@ );
sub tblog ( $@ );
sub tblog_new_process(@);
sub tblog_init_process(@);
sub informative_scriptname();


#
# tblog_init
#
# Called automatically when a script starts.
#
# Will: Get the priority mapping (string -> int) from the database and
# than call tblog_new_process
#
sub tblog_init() {
    return if exists($ENV{'TBLOG_OFF'});

    # Connect to database

    $DB = NewTBDBHandle();

    # Reset default cause

    $ENV{TBLOG_CAUSE} = '';

    # ...

    tblog_new_process(if_defined($main::FAKE_SCRIPTNAME,
				 $REAL_SCRIPTNAME),
		      @ARGV);
};

#
# tblog_new_process CMD, ARGV
#
# Enter a new (possible fake) process, calls tblog_init_process
#
# If used to start a new fake process it is advised to make a local
# copy of %ENV using perl "local".  See tblog_sub_process for an
# explanation.
#
sub tblog_new_process(@) {
    return if exists($ENV{'TBLOG_OFF'});
    delete $ENV{TBLOG_BASE_SCRIPTNAME};
    tblog_init_process(@_);
}

#
# tblog_new_child_process
#
# Enter a new child process.  Called after fork, but should not be
# called if the next action in an exec.
#
sub tblog_new_child_process() {
    tblog_init_process(undef);
}

#
# tblog_init_process CMD, ARGV
#
# Init a new process
#
# Will: (1) Get the unique ID for the script name,  (2) Creating an
# "entring" log message in the database, (3) get the session id and
# set up the environmental variables if they are not already set,
# (4) Get the invocation id, and (5) increment the level
#
# NOTE: Everything is currently stored in the %ENV hash.
#
sub tblog_init_process(@) {
    my ($script, @argv) = @_;
    local $DBQUERY_MAXTRIES = 3;

    return if exists($ENV{'TBLOG_OFF'});

    # Set TBLOG_PID so that we can detect when we are a child. 
    $TBLOG_PID = $$;

    if (defined $script) {

	# Get script name
	
	$ENV{TBLOG_SCRIPTNAME} = $script;
	$ENV{TBLOG_BASE_SCRIPTNAME} = $script unless defined $ENV{TBLOG_BASE_SCRIPTNAME};
	
	# Get script number
	
	$ENV{TBLOG_SCRIPTNUM} = script_name_to_num($ENV{TBLOG_SCRIPTNAME});

	# Reset the child field

	delete $ENV{TBLOG_CHILD};

    } else {

	# We are a child process after a fork

	$ENV{TBLOG_CHILD} = 1;

	@argv = ('...');
    }
	
    # ...

    if (defined $ENV{'TBLOG_SESSION'}) {
	check_env();
	$ENV{TBLOG_LEVEL}++;
	$ENV{TBLOG_PARENT_INVOCATION} = $ENV{TBLOG_INVOCATION};
	my $id = dblog
	    ($NOTICE, {type => 'entering'},
	     'Entering "', join(' ', informative_scriptname(), @argv), '"')
	  or die;
	$ENV{TBLOG_INVOCATION} = $id;
	DBQueryFatal("update log set invocation=$id where seq=$id");
    } else {
	$ENV{TBLOG_SESSION} = 0;
	$ENV{TBLOG_INVOCATION} = 0;
	$ENV{TBLOG_PARENT_INVOCATION} = 0;
	$ENV{TBLOG_LEVEL} = 0;
	$ENV{TBLOG_EXPTIDX} = 0;
	$ENV{TBLOG_UID} = 0;
	$ENV{TBLOG_ATTEMPT} = 0;
	$ENV{TBLOG_CLEANUP} = 0;
	my $id = dblog
	    ($NOTICE, {type => 'entering'},
	     'Entering "', join(' ', informative_scriptname(), @ARGV), '"')
	  or die;
	# set SESSION in database
	$ENV{TBLOG_SESSION} = $id;
	$ENV{TBLOG_INVOCATION} = $id;
	DBQueryFatal("update log set session=$id,invocation=$id where seq=$id");
    }

}


=item tblog_sub_process NAME, ARGV

Began a sub process.  It is advised to make a local copy of %ENV using
perl "local".  This can be done with:

    local %ENV = %ENV

however due to a bug in perl 5.005_03 if "-T" is used than the above will
taint the path, instead use:

    my $old_env = \%ENV
    local %ENV;
    copy_hash %ENV, $old_env

See perlsub(1) for more info on "local"

=cut

sub tblog_sub_process($@) {
    my $name = shift;
    return if exists($ENV{'TBLOG_OFF'});
    tblog_init_process("$ENV{TBLOG_BASE_SCRIPTNAME}-$name",
		       @_);
}

=item tblog_new_session

Force a new session, should be used by daemons before performing some
sort of swap related activity.  The orignal session information will
be lost.

=cut

sub tblog_new_session() {
    return if exists($ENV{'TBLOG_OFF'});
    check_env();
    delete $ENV{TBLOG_SESSION};
    $FORCED_SESSION = 1;
    tblog_init_process($ENV{TBLOG_SCRIPTNAME});
}

=item copy_hash %DEST, \%SRC

Utility function, see tblog_sub_process

=cut

sub copy_hash(\%$) {
    my ($new, $old) = @_;
    foreach (keys %$old) {
	$new->{$_} = $old->{$_};
    }
}

=item tblog_set_info PID, EID, UID

Sets info in the database which can't be derived automatically with
init.  Needs to be called at least once during a session.

=cut

sub tblog_set_info ( $$$ )
{
    check_env();
    my ($pid, $eid, $uid) = @_;
    local $DBQUERY_MAXTRIES = 3;
    $ENV{'TBLOG_EXPTIDX'} = 
	DBQuerySingleFatal("select idx from experiments where pid='$pid' and eid='$eid'");
    $ENV{'TBLOG_UID'} = $uid;
    DBQueryFatal
	sprintf('replace into session_info (session, exptidx, uid) values(%d,%d,%d)',
		$ENV{TBLOG_SESSION}, $ENV{TBLOG_EXPTIDX}, $ENV{TBLOG_UID});
}

=item tblog_set_default_cause CAUSE

Set the default cause.

=cut

sub tblog_set_default_cause ( $ )
{
    check_env();
    $ENV{TBLOG_CAUSE} = $_[0];
}

=item tblog_set_attempt NUM

Set the attempt number to NUM

=cut

sub tblog_set_attempt ( $ )
{
    check_env();
    $ENV{TBLOG_ATTEMPT} = $_[0];
}

=item tblog_inc_attempt

Increment the attempt number

=cut

sub tblog_inc_attempt ()
{
    check_env();
    $ENV{TBLOG_ATTEMPT}++;
}

=item tblog_get_attempt

Get the attempt number

=cut

sub tblog_get_attempt ()
{
    check_env();
    return $ENV{TBLOG_ATTEMPT};
}

=item tblog_set_cleanup BOOL

Set the cleanup bit to BOOL.

=cut

sub tblog_set_cleanup ( $ )
{
    check_env();
    $ENV{TBLOG_CLEANUP} = $_[0];
}

=item tblog_get_cleanup

Get the value of the cleanup bit.

=cut

sub tblog_get_cleanup ()
{
    check_env();
    return $ENV{TBLOG_CLEANUP};
}

=item tblog_exit

Exits a script or sub-process.  Generally called automatically when a
script exists but may be called explistly when ending a sub-process.

=cut

sub tblog_exit() {
    return unless defined $ENV{'TBLOG_SESSION'};
    check_env();
    dblog($INFO, {type=>'exiting'}, "Leaving \"", informative_scriptname(), 
	  " ...\"");
}

#
# informative_scriptname()
#
sub informative_scriptname() {
    my $name;
    if ($ENV{TBLOG_BASE_SCRIPTNAME} eq $REAL_SCRIPTNAME) {
	$name = $ENV{TBLOG_SCRIPTNAME};
    } else {
	$name = "$ENV{TBLOG_SCRIPTNAME} (but really $REAL_SCRIPTNAME)";
    }
    if ($FORCED_SESSION) {
	$name = "forced session in $name";
    } elsif ($ENV{TBLOG_CHILD}) {
	$name = "child of $name";
    }
    return $name;
}


=item tblog PRIORITY, MESG, ...

=item tblog PRIORITY, {PARM=>VALUE,...}, MESG, ...

The main log function.  Logs a message to the database and print
the message to STDERR with an approate prefix depending on the
severity of the error.  If more than one string is given for the
message than they will concatenated.  If the env. var. TBLOG_OFF
is set to a true value than nothing will be written to the
database, but the message will still be written to STDERR.

Useful parms: sublevel, cause, type

=item tberror [{PARM=>VALUE,...},] MESG, ...

=item tberr [{PARM=>VALUE,...},] MESG, ...

=item tbwarn [{PARM=>VALUE,...},] MESG, ...

=item tbwarning [{PARM=>VALUE,...},] MESG, ...

=item tbnotice [{PARM=>VALUE,...},] MESG, ...

=item tbinfo [{PARM=>VALUE,...},] MESG, ...

=item tbdebug [{PARM=>VALUE,...},] MESG, ...

Usefull alias functions.  Will call tblog with the appropriate priority.

=item tbdie [{PARM=>VALUE,...},] MESG, ...

Log the message to the database as an error and than die.  An
optional set of paramaters may be specified as the first argument.
not exactly like die as the message must be specified.

=cut

#
# NOTE: tblog (and friends) defined in libtblog_simple
#

#
# new_seq_num
#
my $sent_cur_log_seq_error_mail = 0;
sub new_seq_num (;$) {
    my ($failure_action) = @_;
    $failure_action = sub {DBFatal("DB Query failed")} unless defined $failure_action;
    my $result;
    $result = DBQuery("UPDATE emulab_indicies SET idx=LAST_INSERT_ID(idx+1) WHERE name = 'cur_log_seq'");
    if (!$result) {
	&$failure_action; 
	return;
    } elsif ($result->affectedrows <= 0) {
	my $subject = "Row \"cur_log_seq\" does not exist in emulab_indicies.";
	my $message = "$subject\n";
	$message .= "Please see \"database-migrate.txt\".";
	SENDMAIL(TB_OPSEMAIL, "DBError - $subject", $message)
	    unless $sent_cur_log_seq_error_mail;
	$sent_cur_log_seq_error_mail = 1;
	die "$subject\n";
	return;
    }
    my $seq = $result->insertid();
    return $seq;
}

#
# dblog(priority, {parm=>value,...}, mesg, ...)
#   Internal function.  Logs a message to the database.  Doesn't print
#   anything. Will not die, instead return 0 on error, with the error
#   message in $@.  Otherwise will return the seq number.
#   Valid parms: sublevel, cause, type
#
use vars '$in_dblog';
$in_dblog = 0; # Used to avoid an infinite recursion when
	       # DBQueryFatal fails as a log entry is made to
	       # record the failure, which will than likely cause
	       # another failure and so on
sub dblog_real ( $$@ ) {
    my ($priority, $parms, @mesg) = @_;
    my $mesg = join('',@mesg);
    my $seq;
    #print SERR "===$priority $parms @mesg\n";
    return if $ENV{TBLOG_OFF} || $in_dblog;
    $in_dblog = 1;
    eval {
	check_env();

	if ($TBLOG_PID != $$) {
	    # Do it here to avoid any possiblty of infinite recursion 
	    # since we are about to set $in_dblog to 0. ...
	    $TBLOG_PID = $$;
	    # $in_dblog is reset locally since tblog_new_child_process 
	    # will call dblog in order to log entering the child process
	    local $in_dblog = 0;
	    tblog_new_child_process();
	}

	my $cause;
	$cause = normalize_cause($parms->{cause}) 
	  if defined $parms->{cause};
	$cause = $priority <= $WARNING ? $ENV{TBLOG_CAUSE} : '' 
	  unless defined $cause;

	my $failure_action;
	local $DBQUERY_MAXTRIES;
	if ($priority <= $NOTICE) {
	    $DBQUERY_MAXTRIES = 3;
	    $failure_action = sub {
		DBFatal("Could not log entry to DB, tblog_find_error may report incorrect results");
	    };
	} else {
	    $DBQUERY_MAXTRIES = 1;
	    $failure_action = sub {
		DBFatal("Could not log entry to DB", 1);
	    };
	}
	
	$seq = new_seq_num($failure_action);
	my $result = DBQuery
	    (sprintf('insert into log (seq,stamp,session,attempt,cleanup,parent,invocation,script,level,sublevel,priority,inferred,cause,type,mesg) '. 
		     'VALUES (%d,UNIX_TIMESTAMP(now()),%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%s,%s)',
		     $seq,
		     $ENV{TBLOG_SESSION}, 
		     $ENV{TBLOG_ATTEMPT},
		     $ENV{TBLOG_CLEANUP},
		     $ENV{TBLOG_PARENT_INVOCATION}, 
		     $ENV{TBLOG_INVOCATION},
		     $ENV{TBLOG_SCRIPTNUM}, 
		     $ENV{TBLOG_LEVEL},
		     if_defined($parms->{sublevel}, 0),
		     $priority,
		     if_defined($parms->{inferred}, 0),
		     DBQuoteSpecial $cause,
		     DBQuoteSpecial if_defined($parms->{type}, 'normal'),
		     DBQuoteSpecial $mesg));
	&$failure_action unless $result;
    };
    $in_dblog = 0;
    # Print a warning on failure but don't log the results to the database
    # as that is likely to fail also
    print SERR format_message(scriptname(), $WARNING, 
			      add_prefix("dblog failed", $@)) if $@;
    return 0 if $@;
    if ($parms->{error}) {
	tbreport($parms->{severity},
		 {seq => $seq, script => $parms->{real_script}},
		 @{$parms->{error}});
    }
    return $seq;
}
{
  local $^W = 0;
  *dblog = \&dblog_real;
}

use constant CONTEXT_MAP => {
    'assign_type_precheck' =>
	['report_context', 'vc0',      'i0',  'i1', 'i2', 'vc1'],
	#                  vtype, requested, slots,  max, round
    'assign_mapping_precheck' =>
	['report_context', 'vc0', 'vc1', 'vc2',      'i0',  'i1'],
	#                  vnode, class,  type, requested, count
    'assign_fixed_node' =>
	['report_context', 'vc0', 'vc1', 'vc2'],
	#                  class, vnode, pnode
    'over_disk_quota' =>
	['report_context',   'vc0'],
	#                  control
    'update_aborted' =>
	['report_context',  'vc0'],
	#                  result
    'set_experiment_state_failed' =>
	['report_context', 'vc0'],
	#                  state
    'archive_op_failed' =>
	['report_context',     'vc0', 'vc1', 'vc2'],
	#                  operation,  type,   dir
    'modify_firewall_not_allowed' =>
	['report_context',     'vc0', 'vc1'],
	#                  operation, state
    'os_node_reset_failed' =>
	['report_context', 'vc0'],
	#                   type
    'assign_wrapper_failed' =>
	['report_context',   'i0'],
	#                  status
    'invalidate_bootblock_failed' =>
	['report_context', 'vc0'],
	#                   node
    'run_command_failed' =>
	['report_context',   'vc0', 'vc1'],
	#                  command,  node
    'node_lacks_linkdelay_support' =>
	['report_context', 'vc0', 'vc1',  'vc2'],
	#                   node,   lan, osname
    'invalid_os' =>
	['report_context', 'vc0',  'vc1', 'vc2'],
	#                   type, osname, pname
    'copy_ns_file_failed' =>
	['report_context', 'vc0', 'vc1'],
	#                    src,  dest
    'bad_data' =>
	['report_context', 'vc0', 'vc1'],
	#                  field,  data
    'bogus_ns_file' =>
	['report_context', 'vc0'],
	#                   path
    'disallowed_directory' =>
	['report_context', 'vc0'],
	#                   path
    'node_boot_failed' =>
	['report_context', 'vc0', 'vc1', 'vc2'],
	#                   node,  type,  osid
    'node_load_failed' =>
	['report_context', 'vc0', 'vc1', 'vc2'],
	#                   node,  type,  osid
    'file_not_found' =>
	['report_context', 'vc0', 'vc1', 'vc2'],
	#                   type,  path,  node
    'invalid_variable' =>
	['report_context', 'vc0', 'vc1'],
	#                   type,   var
    'create_vlan_failed' =>
	['report_context', 'vc0'],
	#                   vlan
    'get_port_status_failed' =>
	['report_context', 'vc0'],
	#                   port
    'device_not_in_stack' =>
	['report_context',  'vc0'],
	#                  device
    'invalid_switch_stack' =>
	['report_context', 'vc0'],
	#                  stack

    'assign_violation' => [
	'report_assign_violation', 
	'unassigned', 'pnode_load', 'no_connect', 'link_users',
	'bandwidth', 'desires', 'vclass', 'delay',
	'trivial_mix', 'subnodes', 'max_types', 'endpoints',
    ],
};

sub tbreport( $@ ) {
    my ($severity) = shift;
    my $parms = {};
    $parms = shift if ref $_[0] eq 'HASH';
    my ($error_type, @context) = @_;
    my $seq = $parms->{seq};

    eval {
	local $DBQUERY_MAXTRIES = 3;
	check_env();

	my $script_num = $ENV{TBLOG_SCRIPTNUM};
	$script_num = script_name_to_num($parms->{script})
	    if defined $parms->{script};

	$seq = new_seq_num() unless defined $seq;
	
	my $session    = $ENV{TBLOG_SESSION};
	my $invocation = $ENV{TBLOG_INVOCATION};
	my $attempt    = $ENV{TBLOG_ATTEMPT};

	croak("error_type must be _0-9A-Za-z") unless $error_type =~ /^\w+$/;

	my $sql = sprintf("insert into report_error (seq, stamp, session, invocation, attempt, severity, script, error_type) values(%d, UNIX_TIMESTAMP(now()), %d, %d, %d, %d, %d, %s)",
			  $seq, $session, $invocation, $attempt, $severity, $script_num, DBQuoteSpecial($error_type));

	DBQueryFatal($sql);

	# XXX: Nuke for now, not used for anything important and is more
	#      trouble than it's worth.  If ever reenabled the arguments
	#      should be checked and a useful error message should be
	#      returned if they are invalid.  Also DBQueryFatal should
	#      probably not be used, instead DBQuery should be used and
	#      special action should be taken on error as done in
	#      dblog_real to avoid generating the DBError email.  Ditto
	#      for the DBQueryFatal above (for report_error). -- kevina
	#if (@context > 0) {
	#    croak("$error_type has no associated entry in CONTEXT_MAP")
	#	unless defined(CONTEXT_MAP->{$error_type}); 
	#
	#   my ($table, @columns) = @{CONTEXT_MAP->{$error_type}};
	#
	#   my $sql = sprintf("insert into %s (seq, " . join(', ', @columns) .
	#		      ") values(%d" . ", %s" x @columns . ")",
	#		      $table, $seq, map(DBQuoteSpecial($_), @context));
	#
	#    DBQueryFatal($sql);
	#}
    };
    # Print a warning on failure but don't log the results to the database
    # as that is likely to fail also
    print SERR format_message(scriptname(), $WARNING, 
			      add_prefix("tbreport failed", $@)) if $@;
    return 0 if $@;
    return $seq;
}

=item tblog_find_error
    
Attempts to find the relevant error.

Will act in a way that is safe to use in an END block, that is (1)
never die, (2) don't modify the exit code. 

Will, also, print the results to and some additional info to STDERR
for diagnosis purposed.

The results will be stored the "errors" table and also returned in a
hash with the following..

    mesg: text of the error
    cause: 
    confidence:
    script:
    session: 
    exptidx:
    err: the text of any internal errors in tblog_find_error,
      otherwise undefined

To retrieve the results from the database:

    SELECT ... WHERE session = <Session ID> FROM errors

The relevant errors are also flagged using "relevant" flag:

    SELECT ... WHERE session = <Session ID>
                 AND relevant != 0 form log

=cut

sub tblog_determine_single_error ( ;$$ );
sub tblog_store_error ($);
sub tblog_dump_error ($);

sub tblog_find_error(;$)
{
    my ($options) = (@_);
    $options = {} unless defined $options;

    my $saved_exitcode = $?;
    my $res;

    eval {
       $res = tblog_determine_single_error();

       my @to_skip;
       my $r = $res;
       while ($r->{cause} eq 'canceled') {
	   push @to_skip, @{$r->{related}};
	   my $to_skip = 'seq NOT IN ('.join(',',@to_skip).')';
	   $r = tblog_determine_single_error(1, $to_skip);
       }
       $res->{other_error} = $r unless $r eq $res;
       my $other_error = $res->{other_error};

       tblog_store_error($res) unless $options->{nostore};

       tblog_dump_error($res) unless $options->{quiet};
    };

    if ($@) {
       $res->{err} = $@;
       eval {SENDMAIL(TB_OPSEMAIL, "tblog_find_error failed",
		      "Experiment: $ENV{TBLOG_EXPTIDX}\n".
		      "User: $ENV{TBLOG_UID}\n".
		      "Session: $ENV{TBLOG_SESSION}\n".
		      "Script: $ENV{TBLOG_SCRIPTNAME}\n".
		      "\n".
		      "$res->{err}\n")};

       eval {tblog $WARNING, add_prefix("tblog_find_error failed", $res->{err})};
    }

    $? = $saved_exitcode;
    return $res;
}

sub tblog_determine_single_error ( ;$$ ) {

    my ($rank, $filter) = @_;
    $rank = 0   unless defined $rank;
    if (defined $filter && $filter) {
	$filter = "AND ($filter)";
    } else {
	$filter = '';
    }
    
    my $session = 0;
    my $error = '';
    my $script = '';
    my $cause = '';
    my $cause_desc;
    my $confidence = 0.0;

    local $DBQUERY_MAXTRIES = 3;

    check_env();
    $session = $ENV{TBLOG_SESSION};

    my ($tblog_revision) = $REVISION_STR =~ /Revision: ([^ \$]+)/ 
	or die "bad REVISON string";

    #
    # Build the Tree
    #
    # Tree data structure:
    # invocation = {invocation => INT, parent => INT, 
    #           [{seq => int ...} || {seq => int, child => invox}]}
    #    
    
    my $root = {invocation => 0, log => []};
    my %lookup = (0 => $root);
    my @log;
    
    my $query_result = DBQueryFatal "select seq,parent,invocation,sublevel,priority,mesg,cause,script_name,type,inferred from log natural join scripts where session = $session and priority <= $NOTICE and attempt <= 1 and not cleanup $filter order by seq";
    
    for (my $i = 0; $i < $query_result->num_rows; $i++) {
	
	my ($seq, $parent, $invocation, $sublevel, $priority, $mesg, $cause, $script, $type, $inferred) 
	    = $query_result->fetchrow;
	
	if (not exists $lookup{$invocation}) {
	    
	    my $p = $lookup{$parent};
	    die "Parent Doesn't Exists!" unless defined $p;
	    $lookup{$invocation} = {invocation => $invocation, 
				    parent => $parent, 
				    script=>$script, 
				    log => []};
	    push @{$p->{log}}, {seq => $invocation, 
				child => $lookup{$invocation}};
	    
	}
	
	push @{$lookup{$invocation}{log}}, {seq => $seq, 
					    invocation=>$invocation, 
					    sublevel=> $sublevel,
					    priority => $priority,
					    type => $type,
					    cause => $cause,
					    inferred => $inferred,
					    mesg => $mesg};
	
    }

    my $handle_sublevels;
    $handle_sublevels = sub {

	my ($tree) = @_;

	my $log = $tree->{log};
	return unless defined $log;

	# normalize sublevels
	my $min_sublevel = 200;
	foreach (@$log) {
	    $min_sublevel = $_->{sublevel} 
	    if exists $_->{sublevel} && $_->{sublevel} < $min_sublevel;
	}

	for (my $i = 0; $i < @$log; $i++) {

	    local $_ = $log->[$i];

	    if (exists $_->{sublevel} && $_->{sublevel} > $min_sublevel) {

		my @sublog = ($_);
		my $j = $i + 1;
		while ($j < @$log && 
		       exists $log->[$j]->{sublevel} &&
		       $log->[$j]->{sublevel} > $min_sublevel) {
		    push @sublog, $log->[$j];
		    $j++;
		}
		my $repl = {
		    child => {log => [@sublog]}
		};
		splice(@$log, $i, $j - $i, $repl);
		$handle_sublevels->($repl->{child})

		} elsif (exists $_->{child}) {

		    $handle_sublevels->($_->{child});

		}
	}

    };

    $handle_sublevels->($root);


    #
    # Now find the relevant errors.
    #
    
    my @related_errors;
    my $find_relevant;
    $find_relevant = sub {

	my ($tree) = @_;

	my @posib_errs;
	my @extra_info;

	foreach (reverse @{$tree->{log}}) {

	    if (exists $_->{child}) {
		
		my @errs = $find_relevant->($_->{child});
		if (@errs) {
		    return (reverse(@extra_info),@errs);
		} 
		
	    } elsif ($_->{priority} <= $ERR) {
		
		push @posib_errs, $_;
		push @related_errors, $_;

		if ($_->{type} eq 'summary') {
		    last;
		} elsif ($_->{type} eq 'extra') {
		    push @extra_info, $_;
		}
		
	    }
	    
	}

	return reverse @posib_errs;
    };

    my @relevant = $find_relevant->($root);
    #
    # Get the most relevent script
    #
    $script = '';
    if (@relevant) {
	$script = $lookup{$relevant[0]->{invocation}}->{script};
    }

    #
    # Figure out the cause;
    #
    my $type = '';
    my $inferred = -1;

    # Assumes that 'extra' info will come first
    
    foreach (@relevant) {
	if (!$cause && $_->{cause}) {
	    $cause = $_->{cause};
	    $type = $_->{type};
	} elsif ($_->{cause} && $_->{type} ne 'extra' &&
		 $_->{type} eq $type && $_->{cause} ne $cause) {
	    $cause = 'unknown';
	}
	$inferred = $_->{inferred} if $inferred < $_->{inferred};
    }
    $cause = 'unknown' unless $cause;

    #
    # Determine need_more_info from error type
    #
    my $need_more_info = -1;
    foreach (@relevant) {
	if ($_->{type} eq 'summary' || $_->{type} eq 'primary') {
	    $need_more_info = 0;
	} elsif ($_->{type} eq 'secondary') {
	    $need_more_info = 1 if $need_more_info == -1;
	}
    }

    #
    # From script determine confidence 
    #
    $confidence = 0.5;
    if ($script =~ /^assign/ && ($cause eq 'temp' || $cause eq 'user')) {
	$confidence = 0.9;
    } elsif ($script =~ /^parse/ && $cause eq 'user') {
	$confidence = 0.9;
    } elsif ($script =~ /^os_setup/ && $type eq 'summary') {
	$confidence = 0.9;
    } elsif ($inferred == 0) {
	$confidence = 0.7;
    } elsif ($inferred == 1) {
	$confidence = 0.6;
    } elsif ($cause ne 'unknown') {
	$confidence = 0.6;
    }


    # 
    # Finally print/store the relevant errors
    #
    
    local $Text::Wrap::columns = 72;
    
    my $prev;
    foreach (@relevant) {
	# avoid printing the exact same error twice
	next if (defined $prev && $prev->{mesg} eq $_->{mesg});

	$error .= "\n" if defined $prev;

	if ($_->{mesg} !~ /\n/) {
	    $error .= expand(wrap('','', "$_->{mesg}\n"));
	} else {
	    # if multiline don't reformat
	    $error .= "$_->{mesg}\n";
	}

	$error .= "...\n" if $need_more_info == 1;

	$prev = $_;
    }
    if (length $error == 0) {
	if ($rank == 0) {
	    $error = "No clue as to what went wrong!\n";
	} else {
	    $error = "";
	}
    }
    chop $error;

    $cause_desc = DBQuerySingleFatal
	"select cause_desc from causes where cause = '$cause'";

    my $script_num =
      ($script ne ''
       ? (DBQuerySingleFatal
	  sprintf ("select script from scripts where script_name=%s",
		   DBQuoteSpecial $script))
       : 0);
    
    return {source=>'find_error', session=>$session, rank=>$rank,
	    exptidx=>$ENV{TBLOG_EXPTIDX},
	    mesg=>$error, cause=>$cause, cause_desc=>$cause_desc,
	    confidence=>$confidence, inferred=>$inferred, 
	    need_more_info=>$need_more_info,
	    script=>$script, script_num=>$script_num,
	    relevant=>[map {$_->{seq}} @relevant],
	    related=>[map {$_->{seq}} @related_errors],
	    tblog_revision => $tblog_revision};
}

sub tblog_store_error ($)
{
    my ($d) = @_;

    croak "Data must be from tblog_find_error not tblog_lookup_error.\n" 
	unless $d->{source} eq 'find_error';

    DBQueryFatal
       sprintf("delete from errors where session = %d", $d->{session});

    DBQueryFatal
	sprintf("insert into errors ".
		"(stamp, exptidx, session, rank, cause, confidence, inferred, need_more_info, script, mesg, tblog_revision) ".
		"values ".
		"(UNIX_TIMESTAMP(now()), %d, %d, %d, %s, %f, %d, %s, %d, %s, %s)",
		$d->{exptidx},
		$d->{session}, $d->{rank}, DBQuoteSpecial($d->{cause}),
		$d->{confidence}, $d->{inferred}, 
		($d->{need_more_info} == -1 ? 'NULL' : $d->{need_more_info}),
		$d->{script_num},
		DBQuoteSpecial($d->{mesg}),
		DBQuoteSpecial($d->{tblog_revision}));
    
    DBQueryFatal
	sprintf("update log set relevant=1 where seq in (%s)",
		join(',', @{$d->{relevant}}))         if @{$d->{relevant}};
}

sub tblog_dump_error ($)
{
    my ($d) = @_;
    print SERR "**** Experimental information, please ignore ****\n";
    print SERR "Session ID = $d->{session}\n";
    print SERR "Likely Cause of the Problem:\n";
    print SERR indent($d->{mesg}, '  ');
    print SERR "Cause: $d->{cause}\n";
    print SERR "Confidence: $d->{confidence}\n";
    print SERR "Script: $d->{script}\n";
    if ($d->{cause} eq 'canceled') {
       my $other_error = $d->{other_error};
       print SERR "\n";
       if (length($other_error->{mesg}) == 0) {
	   print SERR "No other error found.\n";
       } else {
	   print SERR "Possible Error Before Cancellation:\n";
	   print SERR indent($other_error->{mesg}, '  ');
	   print SERR "Cause: $other_error->{cause}\n";
	   print SERR "Confidence: $other_error->{confidence}\n";
	   print SERR "Script: $other_error->{script}\n";
       }
    }
    print SERR "**** End experimental information ****\n";
}

=item tblog_lookup_error [SESSION]

Attempts to retrive the error for SESSION from the database.  Returns
undef if it could't find anything.

=cut

sub tblog_lookup_error ( ;$ ) {

    my ($session) = @_;
    $session = $ENV{TBLOG_SESSION} unless defined $session;

    local $DBQUERY_MAXTRIES = 3;

    my $saved_exitcode = $?;

    my $query_result = DBQueryFatal
	("select session, exptidx, mesg, e.cause, cause_desc, confidence, script_name as script".
	 "  from errors as e, scripts as s, causes as c".
	 "  where e.script = s.script and e.cause = c.cause ".
	 "    and session = $session and rank = 0");

    $? = $saved_exitcode;

    if ($query_result->numrows > 0) {
	return $query_result->fetchrow_hashref;
    } else {
	return undef;
    }
}    

=item tblog_email_error DATA, TO, WHAT, EIDPID, FROM, HEADERS, TBOBS_HEADERS, PREFIX, @FILES

Email the user and possible testbed-ops the error.

DATA is the object returned form tblog_find_error.  It is OK if it is undefined.

WHAT is something like "Swap In Failure", "Swap Out Failure", etc.

=cut

sub tblog_email_error ( $$$$$$$$@ ) {

    my ($d, $to, $what, $pideid, $from, $headers, $tbops_headers, $prefix, @files) = @_;

    carp "TBOBS_HEADERS must be a complete header!  Expect SENDMAIL to fail."  
	unless $tbops_headers =~ /:/;

    my $threshold = 0.55;

    unless ($d->{confidence} > $threshold 
	    && ($d->{cause} eq 'temp' || $d->{cause} eq 'user' 
		|| $d->{cause} eq 'canceled'))
    {
	$headers .= "\n" if defined $headers && length($headers) > 0;
	$headers .= "$tbops_headers";
	$headers .= "\nX-NetBed-Cc: testbed-ops";
    } else {
	$from = "Testbed Ops <testbed-ops\@ops.cloudlab.umass.edu>";
	$headers .= "\n" if defined $headers && length($headers) > 0;
	$headers .= "Bcc: testbed-errors\@ops.cloudlab.umass.edu";
	$headers .= "\nX-NetBed-Cc: testbed-errors";
    }

    my $which = $pideid ? ": $pideid" : "";
    my $subject = "$what$which";

    if ($d->{confidence} > $threshold && $d->{cause} ne 'unknown') {
	$subject = "$what: $d->{cause_desc}$which";
    }
    
    my $body;

    $body .= "$prefix\n\n" if $prefix;

    if ($d->{confidence} > $threshold) {

	$body .= $d->{mesg};
	$body .= "\n";

	if ($d->{cause} eq 'temp') {
	    $body .= "\n";
	    $body .= "Please take a look at this Knowledge Base entry for hints on what to do:\n\n";
	    $body .= "  http://www.cloudlab.umass.edu/kb-show.php3?xref_tag=no_resources\n";
	}

	$headers .= "\nX-NetBed-Cause: $d->{cause}";

    } else {

	$body = 
	    ("Please look at the log below to see what happened.");
    }

    SENDMAIL($to, $subject, $body, $from, $headers, @files);
}

=item tblog_format_error DATA

Format the information in DATA in a format suitable for printing.

DATA is the object returned form tblog_find_error.  It is OK if it is
undefined.

=cut

sub tblog_format_error( $ ) 
{
    my ($d) = @_;
    
    unless (defined $d) {
	$d = {mesg => "No clue as to what went wrong!",
	      cause => 'unknown', cause_desc => 'Cause Unknown',
	      confidence => 0}
    }
	
    my $mesg = '';
    $mesg .= "ERROR:: $d->{cause_desc}\n";
    $mesg .= "\n";
    $mesg .= "$d->{mesg}\n";
    $mesg .= "\n";
    $mesg .= "Cause: $d->{cause}\n";
    $mesg .= "Confidence: $d->{confidence}\n";

    return $mesg;
}

#
# Perl Tie Methods, see perltie(1)
#

sub TIEHANDLE {
    my ($classname, $glob) = @_;
    bless \$glob, $classname;
}

sub PRINT {
    my $this = shift;
    if (IO::Handle::opened($$this)) { # $$this->opened doesn't work 
                                      # with perl 5.005
	print {$$this} @_;
    } else {
	carp "print() on unopened filehandle";
    }
    local $_ = join '', @_; # NOTE: This doesn't take into account "$,"
			    # or output_field_separator
    s/\n$//;
    if (/warning:/i) {
      dblog $WARNING, {inferred=>2}, $_;
    } elsif (/\*\*\*/) {
      dblog $ERR, {inferred=>2}, $_;
    } else {
      dblog $INFO, {inferred=>3}, $_;
    }
}

sub PRINTF {
    my ($this,$format) = (shift, shift);
    &PRINT($this, sprintf($format, @_));
}

sub FILENO {
    my $this = shift;
    fileno($$this);
}

sub OPEN {
    my $this = shift;
    my ($caller_package) = caller;
    # The open must be executed in the callers package becuase of
    # things like "open FH, '>&LOG'" will fail if open is executed in
    # the libtblog package since "LOG" is in the callers package.
    # Since package is a compile time directive, the only way to do
    # this is to do an eval on a string.
    eval("package $caller_package;".
	 '@_ == 1 ? open($$this, $_[0]) : 
          @_ == 2 ? open($$this, $_[0], $_[1]) :
          open($$this, shift, shift, @_)');
}

sub CLOSE {
    # Don't do anything: If we really close $$this than we will lose
    # the fact that SOUT and STDOUT have the same underlying fileno
    # (ditto for SERR and STDERR)
}

=item tblog_start_capture [LIST]

Capture all output to STDOUT and STDERR and turn them into log
messages.  Use SOUT and SERR to print to the real STDOUT and STDERR
respectfully.  Does NOT capture output of subprocesses.  Will also
install handlers for "die" and "warn".

If LIST is present than only capture the parts present in list, can be
any one of "stdout", "stderr", "die", or "warn".

=cut

#
# Implementation node: tie is used to catch prints to STDOUT and
#  STDERR as that seams to be the only sane way to do it.  "print" is
#  a special function in perl and can not be overridden normally.
#  Using "*print = &myprint" or even "*IO::Handle::print = &myprint"
#  will only catch the calls to print without a file handle.  Although
#  it may be possible to catch the other type of call to print I don't
#  know how.
#
sub tblog_start_capture( ;@ ) {
    my (@what) = @_;
    @what = qw(stdout stderr die warn) unless @what;
    foreach (@what) {
	if ($_ eq 'stdout') {
	    tie *STDOUT, 'libtblog', \*SOUT;
	} elsif ($_ eq 'stderr') {
	    tie *STDERR, 'libtblog', \*SERR;
	} elsif ($_ eq 'die') {
	    $SIG{__DIE__} = sub {
		return unless defined $^S; # In Parser
		return if $^S;             # In Eval Block
		tblog_stop_capture();
		local $_ = $_[0];
		s/\n$//;
		dblog($ERR, {inferred=>1, cause=>'internal'}, $_);
		die format_message(scriptname(), $ERR, $_);
	    };
	} elsif ($_ eq 'warn') {
	    $SIG{__WARN__} = sub {
		warn $_[0] unless defined $^S; # In Parser
		local $_ = $_[0];
		s/\n$//;
		dblog($WARNING, {inferred=>1, cause=>'internal'}, $_);
		print SERR "$_\n";
	    };
	} else {
	    carp "Unknown flag in tblog_start_capture: $_";
	}
    }
}

=item tblog_stop_capture [LIST]

Stop capture of STDOUT and STDERR, and remove handles for die and
warn.

If LIST is present than only stop capture of the parts present in
list, can be any one of "stdout", "stderr", "die", or "warn".

=cut

sub tblog_stop_capture( ;@ ) {
    my (@what) = @_;
    @what = qw(stdout stderr die warn) unless @what;
    foreach (@what) {
	if    ($_ eq 'stdout') {untie *STDOUT}
	elsif ($_ eq 'stderr') {untie *STDERR}
	elsif ($_ eq 'die')    {$SIG{__DIE__}  = ''}  
	elsif ($_ eq 'warn')   {$SIG{__WARN__} = ''}
	else 
	  {carp "Unknown flag in tblog_stop_capture: $_"}
    }
}

=item tblog_session

Returns the current session or undefined if it hasn't been defined yet.

=cut

#
# BEGIN
#
tblog_init();
tblog_start_capture();

#
# END
#

END {
    # Save, since shell commands will alter it.
    my $exitstatus = $?;

    tblog_exit();

    $? = $exitstatus;
}

1;

=pod

=back

=head1 ENVIRONMENT

To turn off the database logging set the environmental variable
TBLOG_OFF to a true value.

A number of environmental variables are used by libtblog, all of which
start with "TBLOG_".  They should generally not be set directory.

=head1 SEE ALSO

The file F<libtblog.sql> in the F<sql/> directory in the source describes
the tables used by libtblog.

libtblog_simple, which is a special version of libtblog.

=cut
