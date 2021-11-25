#!/usr/bin/perl -w

#
# Copyright (c) 2020 University of Utah and the Flux Group.
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
# snmpit module for cheap-o 5Gstore UIS-622b remote IP switch or any device
# device that supports the simple URL-based API described in section 6 of:
# https://images-na.ssl-images-amazon.com/images/I/A1yGF9k94JL.pdf
#
# supports new(ip), power(on|off|cyc[le],port), status
#

package power_5gstore;

$| = 1; # Turn off line buffering on output

use strict;
use lib "/users/mshobana/emulab-devel/build/lib";
use libdb;
use emutil;
use MIME::Base64;
use HTTP::Tiny;
use XML::Simple qw(:strict);
use Data::Dumper;

sub Request($;$$);

sub new($$;$) {

    # The next two lines are some voodoo taken from perltoot(1)
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $devicename = shift;
    my $debug = shift;

    if (!defined($debug)) {
	$debug = 0;
    }

    if ($debug) {
	print STDERR "power_5gstore module initializing... debug level $debug\n";
    }

    my $self = {};

    $self->{DEBUG} = $debug;
    $self->{DEVICENAME} = $devicename;
    $self->{NUMOUTLETS} = 2;

    # Fetch authentication credentials from the DB.
    my $res = DBQueryFatal("select key_uid,mykey from outlets_remoteauth ". 
			   "where node_id='$devicename' ".
			   "and key_role='web-passwd'");
    if (!defined($res) || !$res || $res->num_rows() == 0) {
	warn "ERROR: No remote auth info for $devicename.\n";
	return undef;
    } else {
	my $row = $res->fetchrow_hashref();
	$self->{USERNAME} = $row->{'key_uid'};
	$self->{PASSWORD} = $row->{'mykey'};
    }

    bless($self,$class);
    return $self;
}

sub power {
    my $self = shift;
    my $op = shift;
    my @ports = @_;
    my $device = $self->{DEVICENAME};

    my $ctrl;
    if    ($op eq "on")  { $ctrl = 1; }
    elsif ($op eq "off") { $ctrl = 0; }
    elsif ($op =~ /cycle/) { $ctrl = 3; }

    my $errors = 0;

    foreach my $port (@ports) {
	print STDERR "**** Controlling port $port\n" if ($self->{DEBUG} > 1);
	print STDERR "operation is $op ($ctrl)\n" if ($self->{DEBUG} > 2);
	my $xml = $self->Request($port, $ctrl);
	if (!$xml) {
	    print STDERR "$device: Outlet #$port control failed.\n";
	    $errors++;
	    next;
	}
	print STDERR "Control returns: ", Dumper($xml), "\n" if ($self->{DEBUG} > 1);
	#
	# Handle forcecycle and also do some sanity checks
	#
	if (!$xml->{'outlet_status'}) {
	    print STDERR "$device: WARNING: No status returned from control call.\n";
	    next;
	}
	my @vals = split(',', $xml->{'outlet_status'});
	if (scalar(@vals) < $port) {
	    print STDERR "$device: WARNING: No status returned for outlet #$port.\n";
	    next;
	}

	#
	# If forcing and cycle did not result in the outlet being enabled,
	# do a power on.
	#
	my $stat = $vals[$port-1];
	if ($op eq "forcecycle" && $stat == 0) {
	    print STDERR "**** Cycle failed on port $port, turning on...\n" if ($self->{DEBUG});
	    $xml = $self->Request($port, 1);
	    print STDERR "Control returns: ", Dumper($xml), "\n" if ($self->{DEBUG} > 1);
	    @vals = split(',', $xml->{'outlet_status'});
	    $stat = $vals[$port-1];
	}
	if ($self->{DEBUG} &&
	    ($ctrl == 0 && $stat != 0 || $ctrl != 0 && $stat == 0)) {
	    print STDERR "**** port $port in wrong state after $op\n";
	}
    }

    return $errors;
}

sub status {
    my $self = shift;
    my $statusp = shift;
    my %status;

    print STDERR "**** Getting status for ports\n" if ($self->{DEBUG} > 1);
    my $noutlets = $self->{NUMOUTLETS};
    print STDERR "outlets: $noutlets\n" if ($self->{DEBUG} > 2);

    my $xml = $self->Request();
    if (!$xml || !$xml->{'outlet_status'}) {
	print STDERR $self->{DEVICENAME}, ": no status from device\n";
	return 1;
    }
    my @vals = split(',', $xml->{'outlet_status'});
    print STDERR "Status is '", join(' ', @vals), "'\n" if $self->{DEBUG};
    
    my $o = 1;
    foreach my $ostat (@vals) {
	my $outlet = "outlet$o";
	$status{$outlet} = $ostat;
	last if ($o++ > $noutlets);
    }

    if ($statusp) {
	%$statusp = %status;
    }
    return 0;
}

sub MakeAuthStr($)
{
    my ($self) = @_;

    my $auth = $self->{USERNAME} . ":" . $self->{PASSWORD};
    return "Basic " . MIME::Base64::encode_base64($auth, "");
}

#
# Perform an operation on an outlet
#
sub Request($;$$)
{
    my ($self,$outlet,$action) = @_;
    my ($url, $cookie);

    my $server = $self->{DEVICENAME};
  again:
    if (!defined($outlet) || !defined($action)) {
	$url = "http://$server/xml/outlet_status.xml";
    } else {
	my $paramstr = "?target=${outlet}&control=${action}";
	$url = "http://$server/cgi-bin/control.cgi$paramstr";
    }
    print STDERR "URL: $url\n" if ($self->{DEBUG} > 2);

    my %headers = (
	"Keep-Alive" => 300,
	"Connection" => "keep-alive"
    );
    if (defined($cookie)) {
	$headers{'Cookie'} = $cookie;
    } else {
	$headers{'Authorization'} = $self->MakeAuthStr();
    }
    my $http = HTTP::Tiny->new("timeout" => 30);
    my %options = ("headers" => \%headers);

    my $res = $http->request("GET", $url, \%options);
    print STDERR "RESPONSE: ", Dumper($res), "\n" if ($self->{DEBUG} > 2);
    if ($res->{'success'} && $res->{'status'} == "200") {
	if (exists($res->{'headers'}{'content-type'})) {
	    # XXX clunky hack to deal with new firmware
	    if (!$cookie && exists($res->{'headers'}{'location'}) &&
		$res->{'headers'}{'location'} eq "/login.asp?error=1") {
		# XXX expecting a form with user/password info
		my %form = (
		    'login' => 1,
		    'user' => $self->{USERNAME},
		    'password' =>  $self->{PASSWORD}
		    );
		$url = "http://$server/goform/login";
		$res = $http->post_form($url, \%form);
		print STDERR "RESPONSE: ", Dumper($res), "\n" if ($self->{DEBUG} > 2);
		if ($res->{'success'} && $res->{'status'} == "200") {
		    $cookie = $res->{'headers'}{'set-cookie'};
		    goto again;
		}
	    }
	    elsif ($res->{'headers'}{'content-type'} eq "text/xml") {
		my $xml = eval { XMLin($res->{'content'},
				       ForceArray => 0,
				       KeepRoot => 0,
				       KeyAttr => [],
				       SuppressEmpty => undef); };
		if ($@) {
		    print STDERR
			"*** $server: XMLin failed on response string: $@\n";
		    return undef;
		}
		return $xml;
	    }
	}
	print STDERR "*** $server: Non-XML content in response:\n";
	print STDERR Dumper($res->{'content'});
	return undef;
    }
    print STDERR "*** $server: Power control request failed:\n";
    print STDERR Dumper($res);
    return undef;
}

# End with true
1;
