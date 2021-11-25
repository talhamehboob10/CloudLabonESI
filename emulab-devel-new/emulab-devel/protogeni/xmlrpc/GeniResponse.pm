#!/usr/bin/perl -w
#
# Copyright (c) 2008-2021 University of Utah and the Flux Group.
# 
# {{{GENIPUBLIC-LICENSE
# 
# GENI Public License
# 
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and/or hardware specification (the "Work") to
# deal in the Work without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Work, and to permit persons to whom the Work
# is furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Work.
# 
# THE WORK IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE WORK OR THE USE OR OTHER DEALINGS
# IN THE WORK.
# 
# }}}
#
# Perl code to access an XMLRPC server using http. Derived from the
# Emulab library (pretty sure Dave wrote the http code in that file,
# and I'm just stealing it).
#
package GeniResponse;
use strict;
use Exporter;
use vars qw(@ISA @EXPORT);
@ISA    = "Exporter";
@EXPORT = qw (GENIRESPONSE_SUCCESS GENIRESPONSE_BADARGS GENIRESPONSE_ERROR
	      GENIRESPONSE_FORBIDDEN GENIRESPONSE_BADVERSION
	      GENIRESPONSE_SERVERERROR
	      GENIRESPONSE_TOOBIG GENIRESPONSE_REFUSED
	      GENIRESPONSE_TIMEDOUT GENIRESPONSE_DBERROR
	      GENIRESPONSE_RPCERROR GENIRESPONSE_UNAVAILABLE
	      GENIRESPONSE_SEARCHFAILED GENIRESPONSE_UNSUPPORTED
	      GENIRESPONSE_BUSY GENIRESPONSE_EXPIRED GENIRESPONSE_INPROGRESS
	      GENIRESPONSE_ALREADYEXISTS GENIRESPONSE_STRING
              GENIRESPONSE_NOT_IMPLEMENTED
	      GENIRESPONSE_VLAN_UNAVAILABLE GENIRESPONSE_INSUFFICIENT_BANDWIDTH
	      GENIRESPONSE_INSUFFICIENT_NODES GENIRESPONSE_SERVER_UNAVAILABLE
              GENIRESPONSE_INSUFFICIENT_MEMORY GENIRESPONSE_NO_MAPPING
	      GENIRESPONSE_NO_CONNECT GENIRESPONSE_MAPPING_IMPOSSIBLE
	      GENIRESPONSE_STITCHER_ERROR
	      GENIRESPONSE_NOSPACE
	      XMLRPC_PARSE_ERROR XMLRPC_SERVER_ERROR XMLRPC_APPLICATION_ERROR
	      XMLRPC_NO_SUCH_METHOD
	      XMLRPC_SYSTEM_ERROR XMLRPC_TRANSPORT_ERROR
	      HTTP_INTERNAL_SERVER_ERROR HTTP_SERVICE_UNAVAILABLE
	      HTTP_GATEWAY_TIME_OUT GENIRESPONSE_GATEWAY_TIMEOUT
              GENIRESPONSE_NETWORK_ERROR GENIRESPONSE_NETWORK_ERROR_TIMEDOUT
              GENIRESPONSE_NETWORK_ERROR_NOCONNECT
	      GENIRESPONSE_SETUPFAILURE GENIRESPONSE_SETUPFAILURE_OSSETUP
              GENIRESPONSE_SETUPFAILURE_NETWORK
	      GENIRESPONSE_SETUPFAILURE_BOOTFAILED
	      GENIRESPONSE_SETUPFAILURE_EVENTSYS
	      GENIRESPONSE_SETUPFAILURE_INTERRUPTED
	      GENIRESPONSE_SETUPFAILURE_MAXERROR);

use overload ('""' => 'Stringify');
my $current_response = undef;

#
# GENI XMLRPC defs. Also see ../lib/Protogeni.pm.in if you change this.
#
sub GENIRESPONSE_SUCCESS()        { 0; }
sub GENIRESPONSE_BADARGS()        { 1; }
sub GENIRESPONSE_ERROR()          { 2; }
sub GENIRESPONSE_FORBIDDEN()      { 3; }
sub GENIRESPONSE_BADVERSION()     { 4; }
sub GENIRESPONSE_SERVERERROR()    { 5; }
sub GENIRESPONSE_TOOBIG()         { 6; }
sub GENIRESPONSE_REFUSED()        { 7; }
sub GENIRESPONSE_TIMEDOUT()       { 8; }
sub GENIRESPONSE_DBERROR()        { 9; }
sub GENIRESPONSE_RPCERROR()       {10; }
sub GENIRESPONSE_UNAVAILABLE()    {11; }
sub GENIRESPONSE_SEARCHFAILED()   {12; }
sub GENIRESPONSE_UNSUPPORTED()    {13; }
sub GENIRESPONSE_BUSY()           {14; }
sub GENIRESPONSE_EXPIRED()        {15; }
sub GENIRESPONSE_INPROGRESS()     {16; }
sub GENIRESPONSE_ALREADYEXISTS()  {17; }
sub GENIRESPONSE_NOSPACE()        {23; }
sub GENIRESPONSE_VLAN_UNAVAILABLE(){24; }
sub GENIRESPONSE_INSUFFICIENT_BANDWIDTH()  {25; }
sub GENIRESPONSE_INSUFFICIENT_NODES()      {26; }
sub GENIRESPONSE_INSUFFICIENT_MEMORY()     {27; }
sub GENIRESPONSE_NO_MAPPING()              {28; }
sub GENIRESPONSE_NO_CONNECT()              {29; }
sub GENIRESPONSE_MAPPING_IMPOSSIBLE()      {30; }
sub GENIRESPONSE_NETWORK_ERROR()           {35; }
sub GENIRESPONSE_NETWORK_ERROR_TIMEDOUT()  {1;}
sub GENIRESPONSE_NETWORK_ERROR_NOCONNECT() {2;}
sub GENIRESPONSE_NOT_IMPLEMENTED()         {100; }
# These are boot failure indicators.
sub GENIRESPONSE_SETUPFAILURE()            {150; }
sub GENIRESPONSE_SETUPFAILURE_BOOTFAILED() {151; }
sub GENIRESPONSE_SETUPFAILURE_OSSETUP()    {152; }
sub GENIRESPONSE_SETUPFAILURE_NETWORK()    {153; }
sub GENIRESPONSE_SETUPFAILURE_EVENTSYS()   {154; }
sub GENIRESPONSE_SETUPFAILURE_INTERRUPTED(){155; }
sub GENIRESPONSE_SETUPFAILURE_MAXERROR()   {170; }

# Yes, an odd place for this but I need it defined someplace.
sub GENIRESPONSE_STITCHER_ERROR()          {101; }
sub HTTP_INTERNAL_SERVER_ERROR()           {500; }
sub HTTP_SERVICE_UNAVAILABLE()             {503; }
sub HTTP_GATEWAY_TIME_OUT()                {504; }
sub GENIRESPONSE_SERVER_UNAVAILABLE()      {HTTP_SERVICE_UNAVAILABLE();}
sub GENIRESPONSE_GATEWAY_TIMEOUT()         {HTTP_GATEWAY_TIME_OUT();}
sub GENIRESPONSE()		  { return $current_response; }

my @GENIRESPONSE_STRINGS =
    (
     "Success",
     "Bad Arguments",
     "Error",
     "Operation Forbidden",
     "Bad Version",
     "Server Error",
     "Too Big",
     "Operation Refused",
     "Operation Timed Out",
     "Database Error",
     "RPC Error",
     "Unavailable",
     "Search Failed",
     "Operation Unsupported",
     "Busy",
     "Expired",
     "In Progress",
     "Already Exists",
     "Error 18",
     "Error 19",
     "Error 20",
     "Error 21",
     "Error 22",
     "Not Enough Space",
     "Vlan Unavailable",
     "Insufficient Bandwidth",
     "Insufficient Nodes",
     "Insufficient Memory",
     "No Mapping Possible",
     "Error 29",
     "Error 30",
     "Error 31",
     "Error 32",
     "Error 33",
     "Error 34",
     "Server timed out or could not be reached",
    );
$GENIRESPONSE_STRINGS[GENIRESPONSE_NOT_IMPLEMENTED] = "Not Implemented";
sub GENIRESPONSE_STRING($)
{
    my ($code) = @_;

    return "Unknown Error $code"
	if ($code < 0 || $code > scalar(@GENIRESPONSE_STRINGS));

    return $GENIRESPONSE_STRINGS[$code];
}

#
# These are the real XMLRPC errors as defined by the RFC
#
sub XMLRPC_PARSE_ERROR()	{ -32700; }
sub XMLRPC_SERVER_ERROR()       { -32600; }
sub XMLRPC_NO_SUCH_METHOD()     { -32601; }
sub XMLRPC_APPLICATION_ERROR()  { -32500; }
sub XMLRPC_SYSTEM_ERROR()       { -32400; }
sub XMLRPC_TRANSPORT_ERROR()    { -32300; }

#
# This is the (python-style) "structure" we want to return.
#
# class Response:
#    def __init__(self, code, value=0, output=""):
#        self.code     = code            # A RESPONSE code
#        self.value    = value           # A return value; any valid XML type.
#        self.output   = output          # Pithy output to print
#        return
#
# For debugging, stash the method and arguments in case we want to
# print things out.
#
sub new($$;$$$)
{
    my ($class, $code, $value, $output, $logurl) = @_;

    if (!defined($output)) {
	$output = "";
	# Unless its an error, then return standard error string.
	if ($code != GENIRESPONSE_SUCCESS()) {
	    $output = GENIRESPONSE_STRING($code);
	}
    }
    $value = 0
	if (!defined($value));

    my $self = {"code"      => $code,
		"value"     => $value,
		"output"    => $output};
    $self->{"logurl"} = $logurl
	if (defined($logurl));

    bless($self, $class);
    return $self;
}

sub Create($$;$$$)
{
    my ($class, $code, $value, $output, $logurl) = @_;

    if (!defined($output)) {
	$output = "";
	# Unless its an error, then return standard error string.
	if ($code != GENIRESPONSE_SUCCESS()) {
	    $output = GENIRESPONSE_STRING($code);
	}
    }
    $value = 0
	if (!defined($value));

    my $self = {"code"   => $code,
		"value"  => $value,
		"output" => $output};
    $self->{"logurl"} = $logurl
	if (defined($logurl));

    $current_response = $self;
    return $self;
}

#
# Convert hash to a blessed object.
#
sub Bless($$)
{
    my ($class,$ref) = @_;
    bless($ref, $class);
    return $ref;
}
sub Unbless($)
{
    my ($ref) = @_;
    return GeniResponse->Create($ref->code(), $ref->value(),
				$ref->output(), $ref->logurl());
}

# accessors
sub field($$)           { return ($_[0]->{$_[1]}); }
# This is very optional.
sub logurl($) {
    return (exists($_[0]->{"logurl"}) ? $_[0]->{"logurl"} : undef);
}
sub code($;$)
{
    my ($self,$code) = @_;
    if (defined($code)) {
	$self->{'code'} = $code;
    }
    return $self->{'code'};
}
sub value($;$)
{
    my ($self,$value) = @_;
    if (defined($value)) {
	$self->{'value'} = $value;
    }
    return $self->{'value'};
}
sub output($;$) {
    my ($self,$string) = @_;
    if (defined($string)) {
	$self->{'output'} = $string;
    }
    return $self->{'output'};
}
sub error($)
{
    my ($self) = @_;
    my $output = $self->output();

    return $output
	if (defined($output) && $output ne "");

    # Generic error message.
    return GENIRESPONSE_STRING($self->code);
}

# Check for response object. Very bad, but the XML encoder does not
# allow me to intercept the encoding operation on a blessed object.
sub IsResponse($)
{
    my ($arg) = @_;
    
    return (ref($arg) eq "HASH" &&
	    exists($arg->{'code'}) && exists($arg->{'value'}));
}
sub IsError($)
{
    my ($arg) = @_;

    if (ref($arg) eq "GeniResponse") {
	return $arg->code() ne GENIRESPONSE_SUCCESS;
    }
    return (ref($arg) eq "HASH" &&
	    exists($arg->{'code'}) && exists($arg->{'value'}) &&
	    $arg->{'code'} ne GENIRESPONSE_SUCCESS);
}

sub Dump($)
{
    my ($self) = @_;
    
    my $code   = $self->code();
    my $value  = $self->value();
    my $string = $GENIRESPONSE_STRINGS[$code] || "Unknown";
    my $output;

    $output = $self->output()
	if (defined($self->output()) && $self->output() ne "");

    return "code:$code ($string), value:$value" .
	(defined($output) ? ", output:$output" : "");
}

#
# Stringify for output.
#
sub Stringify($)
{
    my ($self) = @_;
    
    my $code   = $self->code();
    my $value  = $self->value();
    my $string = $GENIRESPONSE_STRINGS[$code] || "Unknown";

    return "[GeniResponse: code:$code ($string), value:$value]";
}

sub MalformedArgsResponse($;$)
{
    my (undef,$msg) = @_;
    my $saywhat = "Malformed arguments";
    
    $saywhat .= ": $msg"
	if (defined($msg));

    return GeniResponse->Create(GENIRESPONSE_BADARGS, undef, $saywhat);
}

sub BusyResponse($;$)
{
    my (undef,$resource) = @_;

    $resource = "resource"
	if (!defined($resource));
    
    return GeniResponse->Create(GENIRESPONSE_BUSY,
				undef, "$resource is busy; try again later");
}

sub MonitorResponse($)
{
    my (undef) = @_;

    return GeniResponse->Create(GENIRESPONSE_BUSY,
			undef, "start/restart in progress; try again later");
}

sub BadArgsResponse($;$)
{
    my (undef,$msg) = @_;

    $msg = "Bad arguments to method"
	if (!defined($msg));
    
    return GeniResponse->Create(GENIRESPONSE_BADARGS, undef, $msg);
}

sub SearchFailedResponse($;$)
{
    my (undef,$msg) = @_;

    $msg = "Search Failure"
	if (!defined($msg));
    
    return GeniResponse->Create(GENIRESPONSE_SEARCHFAILED, undef, $msg);
}

sub ServerUnavailableResponse($;$)
{
    my (undef,$msg) = @_;

    $msg = "Server temporarily offline; please try again later"
	if (!defined($msg));
    
    return GeniResponse->Create(GENIRESPONSE_SERVER_UNAVAILABLE, undef, $msg);
}

# _Always_ make sure that this 1 is at the end of the file...
1;
