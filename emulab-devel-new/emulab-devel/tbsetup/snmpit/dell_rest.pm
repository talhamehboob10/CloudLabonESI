#!/usr/bin/perl -w

#
# Copyright (c) 2019-2021 University of Utah and the Flux Group.
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
# Module for Dell OS10 Enterprise RESTCONF API.
# XXX taken from FreeNAS REST API support and probably very similar to other
# REST APIs...
#
# Some of the spec generated here are from trial and error. The rest came
# later and are from turning on "cli mode rest-translate" on an OS10 switch
# and doing the corresponding CLI command to generate a curl command.
#

package dell_rest;
use strict;

use English;
use HTTP::Tiny;
use JSON::PP;
use MIME::Base64;
use Data::Dumper;
use Socket;
use Time::HiRes qw(gettimeofday);

$| = 1; # Turn off line buffering on output

sub new($$$$)
{
    # The next two lines are some voodoo taken from perltoot(1)
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $name = shift;
    my $debugLevel = shift;
    my $userpass = shift;  # username and password

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
	warn "dell_rest: ERROR: must pass in username AND password!\n";
	return undef;
    }

    if ($self->{DEBUG}) {
        print "dell_rest initializing for $self->{NAME}, " .
            "debug level $self->{DEBUG}\n" ;
    }

    # Make it a class object
    bless($self, $class);

    return $self;
}

#
# Make a request via the RESTCONF API.
#   $method is "GET", "PUT", "POST", or "DELETE"
#   $path is the resource path, e.g., "interfaces/ethernet"
#   $datap is a reference to a hash of KEY=VALUE input content (default is ())
#   $exstat is the expected success status code if not the method default
#   $errorp is a reference to a string, used to return error string if !undef
# Return value is the decoded (as a hash) JSON KEY=VALUE returned by request
# Returns undef on failure.
#
sub call($$$;$$$$)
{
    my ($self,$method,$path,$datap,$exstat,$errorp,$raw) = @_;
    my %data = $datap ? %$datap : ();
    my ($datastr,$paramstr);
    my %status = (
	"GET"    => 200,
	"PUT"    => 200,
	"POST"   => 201,
	"DELETE" => 204,
	"PATCH"  => 204
    );

    my $auth = $self->{USERNAME} . ":" . $self->{PASSWORD};
    my $server = $self->{NAME};
    if (keys %data > 0) {
	$datastr = encode_json(\%data);
    } else {
	$datastr = "";
    }

    my $url = "https://$server/restconf/data/$path";
    # we want to know with basic debugging whenever we go to the switch
    print STDERR "dell_rest: make RESTAPI ('$path') $method call to $server\n"
	if ($self->{DEBUG});
    print STDERR "$server: REQUEST: method=$method URL=$url\nCONTENT=$datastr\n"
	if ($self->{DEBUG} > 3);

    my %headers = (
	"Accept"        => "application/json",
	"Authorization" => "Basic " . MIME::Base64::encode_base64($auth, "")
    );
    if ($method eq "POST" || $method eq "PATCH") {
	$headers{"Content-Type"} = "application/json";
    }

    my $http = $self->{HTTP};
    if (!$http) {
	$http = $self->{HTTP} = HTTP::Tiny->new("timeout" => 10);
    }
    my %options = ("headers" => \%headers, "content" => $datastr); 

    my $stamp = gettimeofday()
	if ($self->{DEBUG} > 1);
    my $res = $http->request($method, $url, \%options);
    if ($self->{DEBUG} > 1) {
	$stamp = sprintf "%.3f", gettimeofday() - $stamp;
	print STDERR "$server: RESTAPI ('$path') call done in ${stamp} sec.\n";
	print STDERR "$server: RESPONSE: ", Dumper($res), "\n"
	    if ($self->{DEBUG} > 3);
    }
    $exstat = $status{$method}
	if (!defined($exstat));

    if ($res->{'success'} && $res->{'status'} == $exstat) {
	if (exists($res->{'headers'}{'content-type'}) &&
	    ($res->{'headers'}{'content-type'} eq "application/json" ||
	     $res->{'headers'}{'content-type'} eq "application/yang-data+json")) {
	    return $raw ?
		$res->{'content'} : JSON::PP->new->decode($res->{'content'});
	}
	if (!exists($res->{'content'})) {
	    return {};
	}
	if (!ref($res->{'content'})) {
	    return { "content" => $res->{'content'} };
	}
	my $msg = "Unparsable content: " . Dumper($res->{'content'});
	if ($errorp) {
	    $$errorp = $msg;
	} else {
	    warn("*** ERROR: dell_rest: $msg");
	}
	return undef;
    }
    if ($res->{'reason'}) {
	my $content;

	if (exists($res->{'content'}) &&
	    exists($res->{'headers'}{'content-type'})) {
	    my $ctype = $res->{'headers'}{'content-type'};
	    if ($ctype eq "text/plain") {
		$content = $res->{'content'};
	    } elsif ($ctype eq "application/json" ||
		     $ctype eq "application/yang-data+json") {
		my $cref =
		    JSON::PP->new->decode($res->{'content'});
		if ($cref && ref $cref) {
		    if (exists($cref->{'ietf-restconf:errors'}) &&
			exists($cref->{'ietf-restconf:errors'}->{'error'})) {
			$content = $cref->{'ietf-restconf:errors'}->{'error'};
			$content = @{$content}[0]->{'error-message'};
		    }
		} elsif ($cref) {
		    $content = $cref;
		} else {
		    $content = $res->{'content'};
		}
	    }
	}
	my $msg = "Request failed: " . $res->{'reason'};
	if ($content) {
	    $msg .= "\nRESTCONF error: $content";
	}
	if ($errorp) {
	    $$errorp = $msg;
	} else {
	    warn("*** ERROR: dell_rest: $msg");
	}
	return undef;
    }

    my $msg = "Request failed: " . Dumper($res);
    if ($errorp) {
	$$errorp = $msg;
    } else {
	warn("*** ERROR: dell_rest: $msg");
    }
    return undef;
}

#
# Create a perl hash (suitable for JSON encoding) representing a new VLAN.
#
sub makeVlanSpec($$$)
{
    my ($self,$tag,$name) = @_;

    my $vname = "vlan$tag";
    my $vlanhash = {
	"interface" => [{
	    "type" => "iana-if-type:l2vlan",
	    "enabled" => JSON::PP::true,
	    "description" => "$name",
	    "name" => "$vname"
	}]
    };

    return $vlanhash;
}

#
# Make sure each port appears only once in the given list.
# Returns a new list.
#
# XXX without this, the REST data/interfaces/interface/vlanN PATCH command
# (for adding ports to a VLAN) will fail with "Conflict" and "entry exists".
#
sub uniqueList(@) {
    my (@olist) = @_;

    my %pseen = ();
    my @nlist = ();
    foreach my $p (@olist) {
	if (!exists($pseen{$p})) {
	    push @nlist, $p;
	    $pseen{$p} = 1;
	}
    }
    return @nlist;
}

sub addPortsVlanSpec($$$$)
{
    my ($self,$tag,$uportref,$tportref) = @_;

    my $vname = "vlan$tag";
    my @uports = ($uportref ? @{$uportref} : ());
    my @tports = ($tportref ? @{$tportref} : ());
    my $vlanhash = {
	"interface" => [{
	    "name" => "$vname",
	}]
    };

    if (@uports) {
	$vlanhash->{"interface"}->[0]->{"dell-interface:untagged-ports"} =
	    [uniqueList(@uports)];
    }
    if (@tports) {
	$vlanhash->{"interface"}->[0]->{"dell-interface:tagged-ports"} =
	    [uniqueList(@tports)];
    }
    
    return $vlanhash;
}

sub removeTaggedPortsVlanSpec($$$)
{
    my ($self,$tag,$tportlist) = @_;

    my @ports = uniqueList(@{$tportlist});
    my $vlanhash = {
	"ietf-interfaces:interfaces" => {
	    "dell-interface-range:interface-range" => [{
		"type" => "iana-if-type:l2vlan",
		"name" => "$tag",
		"config-template" => {
		    "dell-interface:tagged-ports" => \@ports,
		    "delete-object" => [ "tagged-ports" ]
		}
	    }]
	}
    };

    return $vlanhash;
}

sub removeVlansSpec($$)
{
    my ($self,@taglist) = @_;

    my $tagstr = join(',', uniqueList(@taglist));
    my $vlanhash = {
	"ietf-interfaces:interfaces" => {
	    "dell-interface-range:interface-range" => [{
		"type" => "iana-if-type:l2vlan",
		"name" => $tagstr,
		"operation" => "DELETE",
	    }]
	}
    };

    return $vlanhash;
}

sub trunkPortSpec($$)
{
    my ($self,$iface) = @_;

    my $porthash = {
	"interface" => [{
	    "name" => "$iface",
	    "dell-interface:mode" => "MODE_L2HYBRID"
	}]
    };

    return $porthash;
}

sub enablePortSpec($$$)
{
    my ($self,$turnon,$iface) = @_;
    my $state = $turnon ? JSON::PP::true : JSON::PP::false;

    my $porthash = {
	"interface" => [{
	    "name" => "$iface",
	    "enabled" => $state
	}]
    };

    return $porthash;
}

sub enableMultiplePortsSpec($$@)
{
    my ($self,$turnon,@ifaces) = @_;
    my $state = $turnon ? JSON::PP::true : JSON::PP::false;

    my @pinfo = ();
    foreach my $iface (uniqueList(@ifaces)) {
	push @pinfo, { "name" => "$iface", "enabled" => $state };
    }

    my $porthash = {
	"ietf-interfaces:interfaces" => {
	    "interface" => \@pinfo
	}
    };
    return $porthash;
}
