#!/usr/bin/perl -w

#
# Copyright (c) 2000-2020 University of Utah and the Flux Group.
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

package libaudit;
use Exporter;

@ISA = "Exporter";
@EXPORT =
    qw ( AuditStart AuditEnd AuditAbort AuditFork AuditSetARGV AuditGetARGV
	 AddAuditInfo
	 LogStart LogEnd LogAbort AuditDisconnect AuditPrefork
	 LIBAUDIT_NODAEMON LIBAUDIT_DAEMON LIBAUDIT_LOGONLY
	 LIBAUDIT_NODELETE LIBAUDIT_FANCY LIBAUDIT_LOGTBOPS LIBAUDIT_LOGTBLOGS
	 LIBAUDIT_DEBUG LIBAUDIT_NOCHILD
       );

# After package decl.
use English;
use POSIX qw(isatty setsid dup2 dup);
use File::Basename;
use IO::Handle;
use Carp;

#
# Testbed Support libraries
#
use libtestbed;
use Brand;

my $TBOPS	= "testbed-ops\@ops.cloudlab.umass.edu";
my $TBAUDIT	= "testbed-audit\@ops.cloudlab.umass.edu";
my $TBLOGS	= "testbed-logs\@ops.cloudlab.umass.edu";
my $OURDOMAIN   = "cloudlab.umass.edu";
my $SCRIPTNAME	= "Unknown";
my $USERNAME    = "Unknown";
my $GCOS        = "Unknown";
my @SAVEARGV	= @ARGV;
my $SAVEPID	= $PID;
my $PREFORKFILE = "/var/tmp/auditfork_$PID";
my $SAVE_STDOUT = 0;
my $SAVE_STDERR = 0;

# Indicates, this script is being audited.
my $auditing	= 0;

# Where the log is going. When not defined, do not send it in email!
my $logfile;

# Sleazy.
my $prefork;

# Logonly, not to audit list.
my $logonly     = 0;
# Log to tbops or tblogs
my $logtblogs   = 0;

# Save log when logging only.
my $savelog     = 0;

# If set than send "fancy" email and also call tblog_find_error
# on errors
my $fancy       = 0;

# We be forked.
my $forked      = 0;

# Do not send email from children, just the parent.
my $nochild     = 0;

# Branding for email. Set via audit info.
my $brand;

# Extra info used when AUDIT_FANCY is set
my %AUDIT_INFO;

# Untainted scriptname for email below.
if ($PROGRAM_NAME =~ /^([-\w\.\/]+)$/) {
    $SCRIPTNAME = basename($1);
}
else {
    $SCRIPTNAME = "Tainted";
}

# The user running the script.
if (my ($name,undef,undef,undef,undef,undef,$gcos) = getpwuid($UID)) {
    $USERNAME = $name;
    $GCOS     = $gcos;
}

#
# Debugging audit is a pain.
#
my $debugfile;

sub DebugAudit($)
{
    my ($msg) = @_;
    
    if (defined($debugfile)) {
	system("/bin/date >> $debugfile");
	system("/bin/echo '$msg' >> $debugfile");
    }
}

#
# Options to AuditStart.
#
sub LIBAUDIT_NODAEMON	{ 0; }
sub LIBAUDIT_DAEMON	{ 0x01; }
sub LIBAUDIT_LOGONLY	{ 0x02; }
sub LIBAUDIT_NODELETE	{ 0x04; }
sub LIBAUDIT_FANCY      { 0x08; } # Only use if libdb and libtblog are
                                  # already in use
sub LIBAUDIT_LOGTBOPS	{ 0x10; }
sub LIBAUDIT_LOGTBLOGS	{ 0x20; }
sub LIBAUDIT_DEBUG	{ 0x40; }
sub LIBAUDIT_NOCHILD	{ 0x80; }

#
# Start an audit (or log) of a script. First arg is a flag indicating if
# the script should fork/detach. The second (optional) arg is a file name
# into which the log should be written. The return value is non-zero in the
# parent, and zero in the child (if detaching).
# 
sub AuditStart($;$$)
{
    my($daemon, $logname, $options) = @_;

    #
    # If we are already auditing, then do not audit a child script. This
    # would result in a blizzard of email! We wrote the scripts, so we
    # should now what they do!
    #
    if (defined($ENV{'TBAUDITON'})) {
	return 0;
    }

    # Reset to default for rentry in log running script.
    $logfile    = undef;
    $prefork    = undef;
    $logonly    = 0;
    $logtblogs  = 0;
    $savelog    = 0;
    $fancy      = 0;
    $forked     = 0;
    $brand      = Brand->Create(); # Default Brand.

    # Logging instead of "auditing" ...
    if (defined($options)) {
	if ($options & LIBAUDIT_NODELETE()) {
	    $savelog = 1;
	}
	if ($options & LIBAUDIT_NOCHILD()) {
	    $nochild = 1;
	}
	if ($options & LIBAUDIT_DEBUG()) {
	    $debugfile = "/var/tmp/auditdebug.$$";
	}
	if ($options & LIBAUDIT_LOGONLY()) {
	    $logonly = 1;

	    if ($options & LIBAUDIT_LOGTBOPS()) {
		$logtbops = 1;
	    }
	    elsif ($options & LIBAUDIT_LOGTBLOGS()) {
		$logtblogs = 1;
	    }
	}
	if ($options & LIBAUDIT_FANCY()) {
	    if (!$INC{"libdb.pm"} || !$INC{"libtblog.pm"}) {
		croak "libdb and libtblog must be loaded when using LIBAUDIT_FANCY";
	    }
	    $fancy = 1;
	}
    }

    #
    # If this is an interactive session, then do not bother with a log
    # file. Just send it to the output and hope the user is smart enough to
    # save it off. We still want to audit the operation though, sending a
    # "what was done" message to the audit list, and CC it to tbops if it
    # exits with an error. But the log is the responsibility of the user.
    #
    if (!$daemon && isatty(STDOUT)) {
	$auditing = 1;
	$ENV{'TBAUDITON'} = "$SCRIPTNAME:$USERNAME";
	return 0;
    }
    # Clear this in case left behind, as for long running process.
    unlink($PREFORKFILE)
	if (-e $PREFORKFILE);

    if (!defined($logname)) {
	$logfile = TBMakeLogname("$SCRIPTNAME");
    }
    else {
	$logfile = $logname;
    }
    $ENV{'TBAUDITLOG'} = $logfile;
    $ENV{'TBAUDITON'}  = "$SCRIPTNAME:$USERNAME";

    #
    # Okay, daemonize.
    #
    if ($daemon) {
	my $mypid = fork();
	if ($mypid) {
	    select(undef, undef, undef, 0.2);
	    return $mypid;
	}
	if (defined(&libtblog::tblog_new_child_process)) {
	    libtblog::tblog_new_child_process();
	}
	# For forked|nochild
	$SAVEPID = $PID;
    }
    $auditing = 1;

    #
    # If setuid, lets reset the owner/mode of the log file. Otherwise its
    # owned by root, mode 600 and a pain to deal with later, especially if
    # the script drops its privs!
    #
    if ($UID != $EUID) {
	chown($UID, $EUID, $logfile);
    }
    chmod(0666, $logfile);

    # Save old stderr and stdout.
    if (!$daemon) {
	$libaudit::SAVE_STDOUT = POSIX::dup(fileno(STDOUT));
	$libaudit::SAVE_STDERR = POSIX::dup(fileno(STDERR));
    }
    open(STDOUT, ">> $logfile") or
	die("opening $logfile for STDOUT: $!");
    open(STDERR, ">> $logfile") or
	die("opening $logfile for STDERR: $!");

    #
    # Turn off line buffering on output
    #
    STDOUT->autoflush(1);
    STDERR->autoflush(1);

    if ($daemon) {
	#
	# We have to disconnect from the caller by redirecting both
	# STDIN and STDOUT away from the pipe. Otherwise the caller
	# will continue to wait even though the parent has exited.
	#
	open(STDIN, "< /dev/null") or
	    die("opening /dev/null for STDIN: $!");

	#
	# Create a new session to ensure we are clear of any process group
	#
        POSIX::setsid() or
	    die("setsid failed: $!");
    }

    return 0;
}

# Logging, not auditing.
sub LogStart($;$$)
{
    my($daemon, $logname, $options) = @_;
    $options = 0
	if (!defined($options));

    return AuditStart($daemon, $logname, $options|LIBAUDIT_LOGONLY());
}

sub LogEnd(;$)
{
    my ($status) = @_;
    
    return AuditEnd($status);
}

sub LogAbort()
{
    return AuditAbort();
}

#
# Finish an Audit. 
#
sub AuditEnd(;$)
{
    my ($status) = @_;

    $status = 0
	if (!defined($status));
    
    SendAuditMail($status);
    delete @ENV{'TBAUDITLOG', 'TBAUDITON'};
    DeleteLogFile()
	if (defined($logfile) && !$savelog);
    return 0;
}

#
# Overwrite our saved argv. Usefull when script contains something that
# should not go into a mail log.
#
sub AuditSetARGV(@)
{
    @SAVEARGV = @_;
}
sub AuditGetARGV()
{
    return @SAVEARGV;
}

#
# Basically, we saying we are not going back.
#
sub AuditDisconnect()
{
    if ($auditing) {
	if (!$daemon && $libaudit::SAVE_STDOUT) {
	    open(FOO, "> /dev/null");
	    
	    POSIX::close($libaudit::SAVE_STDOUT);
	    POSIX::close($libaudit::SAVE_STDERR);

	    $libaudit::SAVE_STDOUT = POSIX::dup(fileno(FOO));
	    $libaudit::SAVE_STDERR = POSIX::dup(fileno(FOO));
	    close(FOO);
	}
    }
}

#
# Abort an Audit. Dump the log file and do not send email.
#
sub AuditAbort()
{
    if ($auditing) {
	$auditing = 0;

	if (!$daemon && $libaudit::SAVE_STDOUT) {
	    POSIX::dup2($libaudit::SAVE_STDOUT, fileno(STDOUT));
	    POSIX::dup2($libaudit::SAVE_STDERR, fileno(STDERR));
	    POSIX::close($libaudit::SAVE_STDOUT);
	    POSIX::close($libaudit::SAVE_STDERR);
	    $libaudit::SAVE_STDOUT = 0;
	    $libaudit::SAVE_STDERR = 0;
	}

	if (defined($logfile)) {
	    #
	    # This should be okay; the process will keep writing to it,
	    # but will be deleted once the process ends and its closed.
	    #
	    DeleteLogFile()
	    	if (!$savelog);
	    undef($logfile);
	}
	delete @ENV{'TBAUDITLOG', 'TBAUDITON'};
	
	if (defined($prefork)) {
	    my $oldmask = umask(0000);
	    system("/usr/bin/touch $prefork");
	    umask($oldmask);
	}
    }
    return 0;
}

#
# Indicate we are about to fork. In general, we want the parent to exit
# first so the first part of the logging email gets sent. Otherwise the
# file might get deleted out from under the child.
# So we use some sleaze to make sure that happens.
#
sub AuditPrefork()
{
    return 0
	if (!$auditing);

    $prefork = $PREFORKFILE;
}

#
# Ug, forked children result in multiple copies. It does not happen often
# since most forks result in an exec.
#
sub AuditFork()
{
    return 0
	if (!$auditing || !defined($logfile));

    #
    # If prefork is set, we want the parent to exit first. So we wait for
    # that to happen.
    #
    if (defined($prefork)) {
	while (! -e $prefork) {
	    sleep(1);
	}
	unlink($prefork);
    }
    $prefork = undef;

    open(LOG, ">> $logfile") or
	die("opening $logfile for $logfile: $!");

    close(STDOUT);
    close(STDERR);
    POSIX::dup2(fileno(LOG), 1);
    POSIX::dup2(fileno(LOG), 2);
    STDOUT->fdopen(1, "a");
    STDERR->fdopen(2, "a");
    close(LOG);

    #
    # Turn off line buffering on output
    #
    STDOUT->autoflush(1);
    STDERR->autoflush(1);

    #
    # Need to close these so that this side of the fork is disconnected.
    # Do NOT close the saved STDOUT/STDERR descriptors until the new
    # ones are open and dup'ed into fileno 1 and 2, and the LOG descriptor
    # closed. This was causing SelfLoader to get confused about something!
    #
    if (!$daemon) {
	POSIX::close($libaudit::SAVE_STDOUT)
	    if ($libaudit::SAVE_STDOUT && $libaudit::SAVE_STDOUT != 1);
	POSIX::close($libaudit::SAVE_STDERR)
	    if ($libaudit::SAVE_STDERR && $libaudit::SAVE_STDERR != 2);
	$libaudit::SAVE_STDOUT = 0;
	$libaudit::SAVE_STDERR = 0;
    }

    #
    # We have to disconnect STDIN from the caller too.
    #
    open(STDIN, "< /dev/null") or
	die("opening /dev/null for STDIN: $!");

    #
    # Create a new session to ensure we are clear of any process group.
    #
    POSIX::setsid();

    # For exit handling.
    $SAVEPID = $PID;
    $forked  = 1;
    
    return 0;
}

#
# Try to delete the log file. We might have to flip back to root.
#
sub DeleteLogFile()
{
    return
	if (!defined($logfile) || $savelog);

    return
	if (unlink($logfile));

    # Failed, try flipping (which will fail of course if not setuid).
    $EUID = 0;
    unlink($logfile);
}

#
# Internal function to send the email. First argument is exit status.
#
# Two messages are sent. A topical message is sent to the audit list. This
# is a short message that says what was done and by who. The actual log of
# what happened is sent to the logs list so that we can go back and see the
# details if needed.
# 
sub SendFancyMail($);
sub SendAuditMail($)
{
    my($exitstatus) = @_;
    
    if ($auditing) {
	# Avoid duplicate messages.
	$auditing = 0;

	# Needs to called here before STDOUT and STDERR is
	# redirectected below
	if ($exitstatus && $fancy) {
	    &libtblog::tblog_find_error(); 
	}

	if (!$daemon && $libaudit::SAVE_STDOUT) {
	    POSIX::dup2($libaudit::SAVE_STDOUT, fileno(STDOUT));
	    POSIX::dup2($libaudit::SAVE_STDERR, fileno(STDERR));
	}

	my $subject  = "$SCRIPTNAME @SAVEARGV";
	if ($exitstatus) {
	    $subject = "Failed: $subject";
	}

	my $body     = "$SCRIPTNAME @SAVEARGV\n" .
	               "Invoked by $USERNAME ($GCOS)";
	if ($exitstatus) {
	    $body   .= "\nExited with status: $exitstatus";
	}
	if (defined($AUDIT_INFO{'message'})) {
	    $body   .= "\n" . $AUDIT_INFO{'message'};
	}
	my $FROM     = "$GCOS <${USERNAME}\@${OURDOMAIN}>";

	if (! $logonly) {
	    $brand->SendEmail($TBAUDIT, $subject, $body, $FROM, undef, ());
	}

	# Success and no log ...
	if ($exitstatus == 0 && !(defined($logfile) && -s $logfile)) {
	    # Do not save empty logfile. 
	    DeleteLogFile()
		if (defined($logfile));
	    goto done;
	}

	if ($fancy) {
	    SendFancyMail($exitstatus);
	    goto done;
	}

	#
	# Send logfile to tblogs. Carbon to tbops if it failed. If no logfile
	# then no point in sending to tblogs, obviously.
	#
	my $TO;
	my $HDRS  = "Reply-To: $TBOPS";
	my @FILES = ();
	
	if (defined($logfile) && -s $logfile) {
	    @FILES = ($logfile);

	    if ($logonly) {
		if (defined($AUDIT_INFO{'to'})) {
		    $TO    = join(', ', @{ $AUDIT_INFO{'to'} });
		}
		elsif ($logtbops) {
		    $TO    = $TBOPS;
		}
		elsif ($logtblogs) {
		    $TO    = $TBLOGS;
		    $HDRS .= "\nCC: $TBOPS" if ($exitstatus);
		}
		else {
		    $TO    = $FROM;
		    $HDRS .= "\nCC: ". ($exitstatus ? $TBOPS : $TBLOGS);
		}
	    }
	    else {
		$TO    = $TBLOGS;
		$HDRS .= "\nCC: $TBOPS" if ($exitstatus);
	    }
	}
	elsif ($logtblogs) {
	    $TO    = $TBLOGS;
	    $HDRS .= "\nCC: $TBOPS" if ($exitstatus);
	}
	else {
	    $TO    = $TBOPS;
	}
	if (defined($AUDIT_INFO{'cc'})) {
	    $HDRS .= "\n";
	    $HDRS .= "CC: " . join(', ', @{ $AUDIT_INFO{'cc'} });
	}

	# This always succeeds, stop leaving file in /tmp
	$brand->SendEmail($TO, $subject, $body, $FROM, $HDRS, @FILES);
	DeleteLogFile()
	    if (defined($logfile) && !$savelog);

      done:
	system("/usr/bin/touch $prefork")
	    if (defined($prefork));
    }
}

sub SendFancyMail($)
{
    import libdb;
    import libtblog;
    import User;

    my ($exitstatus) = @_;
    
    my ($TO, $FROM);
    my ($name, $email);
    my $this_user = User->ThisUser();
    if (defined($this_user)) {
	$name  = $this_user->name();
	$email = $this_user->email();
	$TO    = "$name <$email>";
    } else {
	$TO = "$GCOS <${USERNAME}\@${OURDOMAIN}>";
    }
    $FROM = $TO;

    my @FILES;
    
    if (defined($logfile) && -s $logfile) {
	@FILES = ($logfile);
    }

    # Avoid sending a person the same email twice
    my $extra_cc;
    if (defined ($AUDIT_INFO{cc})) {
	my @cc;
	my @prev_emails = ($email);
	OUTER: foreach (@{$AUDIT_INFO{cc}}) {
	    ($email) = /([^<> \t@]+@[^<> \t@]+)/;
	    foreach my $e (@prev_emails) {
		next OUTER if $email eq $e;
		push @prev_email, $e;
	    }
	    push @cc, $_;
	}
	if (@cc) {
	    $extra_cc = "Cc: ";
	    $extra_cc .= join(', ', @cc);
	}
    }

    my $sendmail_res;
    if ($exitstatus) {
	my $d = tblog_lookup_error();
	my $prefix;
	$prefix .= "$SCRIPTNAME @SAVEARGV\n";
	$prefix .= "Exited with status: $exitstatus";
	my $what = "Failed: $SCRIPTNAME";
	$what = $AUDIT_INFO{failure_frag} if defined $AUDIT_INFO{failure_frag};
	$which = $AUDIT_INFO{which};

	# Ick.
	local $libtestbed::MAILTAG = $brand->EmailTag();
    
	$sendmail_res 
	    = tblog_email_error($d, $TO, $what,	$which, 
				$FROM, $extra_cc, "Cc: $TBOPS",
				$prefix, @FILES);
    } else {

	my $subject  = "$SCRIPTNAME succeeded";
	$subject = $AUDIT_INFO{success_frag} if defined $AUDIT_INFO{success_frag};
	$subject .= ": $AUDIT_INFO{which}" if defined $AUDIT_INFO{which};
	my $body     = "$SCRIPTNAME @SAVEARGV\n";

	my $HDRS;
	$HDRS .= "$extra_cc\n" if defined $extra_cc;
	$HDRS .= "Reply-To: $TBOPS\n";
	$HDRS .= "Bcc: $TBLOGS";
	
	$sendmail_res 
	    = $brand->SendEmail($TO, $subject, $body, $FROM, $HDRS, @FILES);
    }
    
    if ($sendmail_res) {
	DeleteLogFile()
	    if (defined($logfile) && !$savelog);
    }
}


# Info on possibe values for AUDIT_INFO
# [KEY => string|list]
my %AUDIT_METAINFO = 
    ( which => 'string',        # ex "PROJ/EXP"
      success_frag => 'string', # ex "T. Swapped In"
      failure_frag => 'string', # ie "Bla Failure"
      message      => 'string',
      to           => 'list',   # Send audit mail to these people
      cc           => 'list',   # Cc audit mail to these people
      brand        => 'brand'); # Brand object for sendmail

#
# AddAuditInfo($key, $value)
#   add additional information for libaudit to use in SendAuditMail
#   when AUDIT_FANCY is set
#
# TODO: Eventually child scripts should be able to use AddAuditInfo, not 
#   just the script in which AuditStart(...) was called.  This will probably
#   involve storing the values in the database somehow.
#
sub AddAuditInfo ($$) {
    my ($key, $value) = @_;

    if (!$auditing) {

	carp "AddAuditInfo($key, ...) ignored since the script isn't being audited.";
	return 0;

    }

    if ($AUDIT_METAINFO{$key} eq 'string') {

	$AUDIT_INFO{$key} = $value;
	return 1;

    } elsif ($AUDIT_METAINFO{$key} eq 'list') {

	push @{$AUDIT_INFO{$key}}, $value;
	return 1;

    } elsif ($AUDIT_METAINFO{$key} eq 'brand') {
	$brand = $value;
    } else {

	carp "Unknown key, \"$key\" in AddAuditInfo";
	return 0;

    }
}

#
# When the script ends, if the audit has not been sent, send it. 
# 
END {
    return
	if (($forked || $nochild) && $PID != $SAVEPID);
    
    # Save, since shell commands will alter it.
    my $exitstatus = $?;
    
    SendAuditMail($exitstatus);

    $? = $exitstatus;
}

1;
