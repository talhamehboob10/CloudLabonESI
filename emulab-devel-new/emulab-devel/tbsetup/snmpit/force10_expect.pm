#!/usr/bin/perl -w

#
# Copyright (c) 2013-2021 University of Utah and the Flux Group.
# Copyright (c) 2006-2014 Universiteit Gent/iMinds, Belgium.
# Copyright (c) 2004-2006 Regents, University of California.
# 
# {{{EMULAB-LGPL
# 
# This file is part of the Emulab network testbed software.
# 
# This file is free software; you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation; either version 2.1 of the License, or (at
# your option) any later version.
# 
# This file is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
# License for more details.
# 
# You should have received a copy of the GNU Lesser General Public License
# along with this file.  If not, see <http://www.gnu.org/licenses/>.
# 
# }}}
#

#
# Expect module for Force10 switch cli interaction.  A thousand curses to
# Force10 Networks that this module had to be written at all...
#

package force10_expect;
use strict;
use Data::Dumper;

$| = 1; # Turn off line buffering on output

use English;
use Expect;
# Need this to get our TB prefix.
use libtestbed;
my $TB = libtestbed::TBPREFIX();

#
# Gack! we run snmpit as the user, which means the ssh command to create
# the expect object will run as the user, and that means ssh will load the
# user's ssh config file and the user's ssh private key. The former is easy
# to deal with (via the -F command) but there is no way to convince ssh not
# to load any keys unless we give it a -i command. Why does this matter?
# Well, users are prone to messing with the keys we create for them in
# their home dir, and if they mess those up or encrypt them, the ssh
# command can hang up asking for a key passphrase. In general, we want to
# remove all reference to the user's environment anyway, so we are going to
# force ssh to use a well known unencrypted key. If that key does not
# exist, throw back an error early.
#
my $SSHKEY = "$TB/etc/switch_sshrsa";

# Constants
my $CONN_TIMEOUT = 60;
my $CLI_TIMEOUT  = 15;
my $DEBUG_LOG    = "/tmp/force10_expect_debug.log";

sub new($$$$$) {

    # The next two lines are some voodoo taken from perltoot(1)
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $name = shift;
    my $debugLevel = shift;
    my $userpass = shift;  # username and password
    my $options = shift;

    #
    # Key must exist.
    #
    if (! -e $SSHKEY) {
	warn "force10_expect: $SSHKEY does not exist!\n";
	return undef;
    }

    #
    # Create the actual object
    #
    my $self = {};

    #
    # Set the defaults for this object
    # 
    if (defined($debugLevel)) {
        $self->{DEBUG} = $debugLevel;
    } else {
        $self->{DEBUG} = 0;
    }

    $self->{NAME} = $name;
    ($self->{USERNAME}, $self->{PASSWORD}) = split(/:/, $userpass);
    if (!$self->{USERNAME} || !$self->{PASSWORD}) {
	warn "force10_expect: ERROR: must pass in username AND password!\n";
	return undef;
    }

    if ($self->{DEBUG}) {
        print "force10_expect initializing for $self->{NAME}, " .
            "debug level $self->{DEBUG}\n" ;
    }

    if (exists($options->{"hostname"})) {
	$self->{CLI_PROMPT} = $options->{"hostname"} . "#";
    }
    else {
	$self->{CLI_PROMPT} = "$self->{NAME}#";
    }

    # Make it a class object
    bless($self, $class);

    #
    # Lazy initialization of the Expect object is adopted, so
    # we set the session object to be undef.
    #
    $self->{SESS} = undef;

    return $self;
}

#
# Create an Expect object that spawns the ssh process 
# to switch.
#
sub createExpectObject($)
{
    my $self = shift;
    my $id = "$self->{NAME}::createExpectObject()";
    my $error = 0;
    my $spawn_cmd = "ssh -F /dev/null -o UserKnownHostsFile=/dev/null ".
	"-o IdentitiesOnly=yes -o StrictHostKeyChecking=no -i $SSHKEY ".
	"-c 3des-cbc -l $self->{USERNAME} $self->{NAME}";
    # Create Expect object and initialize it:
    my $exp = new Expect();
    if (!$exp) {
        # upper layer will check this
        return undef;
    }
    $exp->raw_pty(0);
    $exp->log_stdout(0);

    if ($self->{DEBUG} > 2) {
	$exp->log_file($DEBUG_LOG,"w");
	$exp->debug(1);
    }

    if (!$exp->spawn($spawn_cmd)) {
	warn "$id: Cannot spawn $spawn_cmd: $!\n";
	return undef;
    }
    $exp->expect($CONN_TIMEOUT,
         [qr/$self->{USERNAME}\@$self->{NAME}(\.[-\w\.]+)?\'s password:/ =>
	  sub { my $e = shift;
		$e->send($self->{PASSWORD}."\n");
		exp_continue;}],
         ["Permission denied" => sub { $error = "Password incorrect!";} ],
         [ timeout => sub { $error = "Timeout connecting to switch!";} ],
         $self->{CLI_PROMPT} );

    if (!$error && $exp->error()) {
	$error = $exp->error();
    }

    if ($error) {
	warn "$id: Could not connect to switch: $error\n";
	return undef;
    }

    return $exp;
}

#
# Utility function - return the configuration prompt string for a given
# interface name.
#
sub conf_iface_prompt($$) {
    my ($self, $iface) = @_;
    my $suffix = "";
    IFNAME: for ($iface) {
	/vlan(\d+)/i && do {$suffix = "vl-$1"; last IFNAME;};
	/(te|fo)(\d+\/\d+)/i && do {$suffix = "$1-$2"; last IFNAME;};
	/po(\d+)/i && do {$suffix = "po-$1"; last IFNAME;};
	return undef; # default case: invalid/unhandled iface name
    }
    return $self->{NAME} . '(conf-if-' . $suffix . ')#';
}

#
# Run a CLI command (or config command), checking for errors.
#
# Parameters:
# $cmd - The CLI command to run in the given context.
# $confmode - Is this a configuration command? 1 for yes, 0 for no
# $iface - Name of interface to exec config command against.
#
sub doCLICmd($$;$$)
{
    my ($self, $cmd, $confmode, $iface) = @_;
    $confmode ||= 0;
    $iface    ||= "";

    my $output = "";
    my $error = "";
    my @active_sets;

    my $exp = $self->{SESS};
    my $id = "$self->{NAME}::doCLICmd()";

    $self->debug("$id: called with: '$cmd', '$confmode', '$iface'\n",1);

    if (!$exp) {
	#
	# Create the Expect object, lazy initialization.
	#
	# We'd better set a long timeout on Apcon switch
	# to keep the connection alive.
	$self->{SESS} = $self->createExpectObject();
	if (!$self->{SESS}) {
	    warn "WARNING: Unable to connect to $self->{NAME}\n";
	    return (1, "Unable to connect to switch $self->{NAME}.");
	}
	$exp = $self->{SESS};
    }

    # Common patterns
    my $catch_error_pat  = [qr/% Error: (.+?)\n/,
			    sub {my $e = shift; $error = ($e->matchlist)[0];
				 exp_continue;}];
    my $timeout_pat      = [timeout => sub { $error = "timed out.";}];
    my $get_output_pat   = [$self->{CLI_PROMPT}, sub {my $e = shift; 
						      $output = $e->before();}];

    # Common pattern sets
    my $get_output_set = [$get_output_pat];

    #
    # Sets of pattern sets for execution follow.
    #

    # Just pop off one command without going into config mode.
    my @single_command_sets = ();
    push (@single_command_sets,
	  [
	     [$self->{CLI_PROMPT}, sub {my $e = shift; $e->send("$cmd\n")}]
	  ],
	  $get_output_pat
	);

    # Perform a single config operation (go into config mode).
    my @single_config_sets = ();
    push (@single_config_sets,
	  [
	     [$self->{CLI_PROMPT}, sub {my $e = shift; 
					$e->send("conf t\n$cmd\nend\n");}]
	  ],
	  $get_output_pat
	);

    # Do an interface config operation (go into iface-specific config mode).
    my @iface_config_sets = ();
    push (@iface_config_sets,
	  [
	     [$self->{CLI_PROMPT}, sub {my $e = shift; 
					$e->send("conf t\ninterface $iface\n$cmd\nend\n");}]
	  ],
	  $get_output_pat
	);

    # Pick "set of sets" to use with Expect based on how this method
    # was called.
    if ($confmode) {
	if ($iface) {
	    @active_sets = @iface_config_sets;
	} else {
	    @active_sets = @single_config_sets;
	}
    } else {
	@active_sets = @single_command_sets;
    }

    $exp->clear_accum();
    $exp->send("\cC"); # Get a command prompt into the Expect accumulator.
    # Match across the selected set of patterns.
    my $i = 1;
    foreach my $patset (@active_sets) {
	$self->debug("Match set: $i.\n",2);
	$i++;
	$exp->expect($CLI_TIMEOUT,
		     $catch_error_pat,
		     @$patset,
		     $timeout_pat);
	if ($error || $exp->error()) {
	    $self->debug("error string: $error\n",2);
	    $self->debug("exp error: " . ($exp->error()) . "\n",2);
	} else {
	    $self->debug("exp match:  " . ($exp->match()) . "\n",2);
	}
	$self->debug("exp before: " . ($exp->before()) . "\n",2);
	$self->debug("exp after:  " . ($exp->after()) . "\n",2);
    }

    if (!$error && $exp->error()) {
	$error = $exp->error();
    }

    if ($error) {
	$self->debug("$id: Error in doCLICmd: $error\n",1);
        return (1, $error);
    } else {
        return (0, $output);
    }
}

#
# Prints out a debugging message, but only if debugging is on. If a level is
# given, the debuglevel must be >= that level for the message to print. If
# the level is omitted, 1 is assumed
#
# Usage: debug($self, $message, $level)
#
sub debug($$;$) {
    my $self = shift;
    my $string = shift;
    my $debuglevel = shift;
    if (!(defined $debuglevel)) {
        $debuglevel = 1;
    }
    if ($self->{DEBUG} >= $debuglevel) {
        print STDERR $string;
    }
}
