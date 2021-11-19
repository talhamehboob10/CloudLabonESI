#!/usr/bin/perl -w

#
# Copyright (c) 2016 University of Utah and the Flux Group.
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

package libjsonrpc;
use Exporter;

@ISA = "Exporter";
@EXPORT =
    qw ( EncodeCall EncodeResult EncodeError 
         DecodeRPCData SendRPCData RecvRPCData );

# After package decl.
use English;
use JSON;
use Data::Dumper;

# Constants
my $MAXFID = 100;

# Global variables
our $debug = 0;
my $FID = 0;
my %fid2func = ();
my $PDUBUF = '';
my $PDUBUFSIZ = 10_000;
my $SEPSTR = "\r\n\r\n";
my $MINTMO = 1; # No less than 1 second
my $MAXTMO = 300; # No more than 5 minutes

sub _getNextFID($) {
    my ($func) = @_;
    my $wrapped = 0;

    while (1) {
	$FID++;
	if (!exists($fid2func{$FID})) {
	    return $FID;
	}

	if ($FID > $MAXFID) {
	    if ($wrapped) {
		die "FID wrapped and no free FID slot found!\n";
	    }
	    warn "libjsonrpc::GetNextFid: Warning: FID wrapped!\n";
	    $FID = 1;
	    $wrapped = 1;
	}
    }

    die "libjsonrpc::GetNextFid: Control should never reach here!";
}

sub EncodeCall($;$) {
    my ($func, $args) = @_;
    
    if (!$func) {
	warn "libjsonrpc::EncodeCall: No function call specified!\n";
	return undef;
    }

    my $fid = _getNextFID($func);

    # We don't check or validate the arguments in any way.  That will be
    # up to the receiving end to do in context.  If they can be JSON encoded,
    # all is well from this encoding function's perspective. Also, if 
    # nothing is passed in for $args, it will be passed along here as undefined
    # to the json encoder which will in turn convert it to a JSON 'null'.
    warn "libjsonrpc::EncodeCall: encoding '$func'\nArgs:\n" . Dumper($args)
	if $debug;
    my $json_text = eval { to_json({FID      => $fid,
				    FUNCTION => $func, 
				    ARGS     => $args}); };
    if ($@) {
	warn "Error encoding function call to JSON data: $@\n";
	return undef;
    }
    if (!$json_text) {
	warn "libjsonrpc::EncodeCall: Nothing returned by to_json!\n";
	return undef;
    }

    $fid2func{$fid} = $func;

    return $json_text;
}

sub EncodeResult($$) {
    my ($fid, $results) = @_;

    if (!$fid) {
	warn "TBDB::EncodeResult: A valid function call ID must be given!";
	return undef;
    }

    # We don't check or validate results in any way.  That will be
    # up to the receiving end to do in context.  If they can be JSON encoded,
    # all is well from this encoding function's perspective.
    my $json_text = to_json({FID    => $fid, 
			     RESULT => $results});
    if (!$json_text) {
	warn "libjsonrpc::EncodeResult: Nothing returned by to_json!\n";
	return undef;
    }

    return $json_text;
}

sub EncodeError($$;$) {
    my ($fid, $code, $message) = @_;

    if (!$fid || $fid < 1 || !defined($code)) {
	warn "libjsonrpc::EncodeError: Must provide valid FID and code id!\n";
	return undef;
    }

    $message ||= "(No Message)";

    my $json_text = to_json({FID => $fid, 
			     ERROR => {CODE => $code, MESSAGE => $message}});

    if (!$json_text) {
	warn "libjsonrpc::EncodeError: Nothing returned by to_json!\n";
	return undef;
    }

    return $json_text;
}

sub DecodeRPCData($) {
    my ($json_text) = @_;

    if (!$json_text) {
	warn "libjsonrpc::DecodeRPCData: No data to decode!\n";
	return undef;
    }

    my $data = eval { from_json($json_text); };
    if ($@) {
	warn "Error trying to decode JSON data: $@\n";
	return undef;
    }

    if (ref($data) ne "HASH") {
	warn "Did not parse out a hash from JSON data!\n";
	return undef;
    }

    if (!exists($data->{FID})) {
	warn "No FID (function ID) found in JSON data!\n";
	return undef;
    }

    my $fid = $data->{FID};

    if (exists($data->{FUNCTION})) {
	warn "libjsonrpc::DecodeRPCData: Function $data->{FUNCTION} called.\n"
	    if $debug;
    }
    elsif (exists($data->{RESULT})) {
	if (!exists($fid2func{$fid}) && $fid != -1) {
	    warn "libjsonrpc::DecodeRPCData: Unknown FID in results: $fid\n";
	} else {
	    warn "libjsonrpc::DecodeRPCData: Results returned for FID $fid ($fid2func{$fid})\n"
		if $debug;
	    delete $fid2func{$fid};
	}
    }
    elsif (exists($data->{ERROR})) {
	if (!exists($fid2func{$fid})) {
	    warn "libjsonrpc::DecodeRPCData: Unknown FID in error: $fid\n";
	} else {
	    warn "libjsonrpc::DecodeRPCData: Error returned for FID $fid ($fid2func{$fid})\n"
		if $debug;
	    delete $fid2func{$fid};
	}
    }
    else {
	warn "libjsonrpc::DecodeRPCData: Unidentifiable RPC data!\n";
	return undef;
    }

    return $data;
}

sub SendRPCData($$) {
    my ($fh, $encdata) = @_;

    if (!$fh) {
	warn "libjsonrpc::SendRPCData: Must provide valid filehandle!\n";
	return 0;
    }

    if (!$encdata) {
	warn "libjsonrpc::SendRPCData: Must provide data to send!\n";
	return 0;
    }

    warn "libjsonrpc::SendRPCData: sending: $encdata\n"
	if $debug;

    $encdata .= $SEPSTR;
    my $res = eval { print $fh $encdata };
    if ($@) {
	warn "libjsonrpc::SendRPCData: Error while attempting to send data: $@";
	return 0;
    }

    if (!$res) {
	warn "libjsonrpc::SendRPCData: Printing to filehandle failed: $!";
	return 0;
    }

    return 1;
}

sub _getPDU() {
    my $index = index($PDUBUF, $SEPSTR);
    if ($index == -1) {
	warn "libjsonrpc::GetPDU: PDU separator not found in buffer.\n"
	    if $debug;
	return undef;
    }

    my $retval = substr($PDUBUF, 0, $index);
    $PDUBUF = substr($PDUBUF, $index + length($SEPSTR));
    return $retval;
}

sub RecvRPCData($$;$) {
    my ($fh, $ppdu, $timeout) = @_;
    my $PDU;

    $timeout = $MAXTMO if (!defined($timeout));

    if (!$fh) {
	warn "libjsonrpc::RecvRPCData: Must provide valid filehandle!\n";
	return 0;
    }

    if (!$ppdu || ref($ppdu) ne "SCALAR") {
	warn "libjsonrpc::RecvRPCData: Must pass in a scalar reference for holding data!\n";
	return 0;
    }

    if ($timeout && ($timeout < $MINTMO || $timeout > $MAXTMO)) {
	warn "Timeout is out of bounds ($MINTMO < timeout < $MAXTMO): $timeout\n";
	return 0;
    }

    my $bits = '';
    vec($bits, fileno($fh), 1) = 1;

    while (!($PDU = _getPDU())) {
	my $nready = select($bits, undef, undef, $timeout);
	if (!$nready) {
	    warn "libjsonrpc::RecvRPCData: Timeout while waiting for data!\n"
		if $debug;
	    return -1;
	}
	warn "libjsonrpc::RecvRPCData: input filehandle has data.\n"
	    if $debug;

	my $nbytes = sysread($fh, $PDUBUF, $PDUBUFSIZ, length($PDUBUF));
	if (!defined($nbytes)) {
	    warn "libjsonrpc::RecvRPCData: Error reading RPC data from file handle: $!\n";
	    return 0;
	}
	elsif ($nbytes == 0) {
	    warn "libjsonrpc::RecvRPCData: Premature EOF?\n"
		if $debug;
	    return 0;
	}
    }

    $$ppdu = $PDU;
    return 1;
}

# Mandatory fun
1;
