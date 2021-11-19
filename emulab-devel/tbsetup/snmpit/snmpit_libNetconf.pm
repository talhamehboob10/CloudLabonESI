#!/usr/bin/perl -w

#
# Copyright (c) 2015-2020 University of Utah and the Flux Group.
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
# Netconf handler/adapter class.  Hides the connection management, XML
# method invocation, and response parsing goo from the caller. However,
# callers are still responsible for creating switch-model-specific XML
# structures for filters, and parsing such data as returned by RPCs.
#
# Note: This is NOT a comprehensive implementation of the Netconf protocol!
#

package snmpit_libNetconf;

use Exporter qw( import );
@EXPORT = qw ( NCRPCOK NCRPCDATA NCRPCRAWRES NCRPCERR );

use Expect;
use XML::LibXML;
use Data::Dumper;

use strict;

$| = 1; # Turn off line buffering on output

##############################################################################
#
# Constants
#

my $CONN_TIMEOUT   = 60; # 60 seconds
my $CLI_TIMEOUT    = 15; # 15 seconds
my $DEBUG_LOG      = "/tmp/Netconf_expect_debug.log";
my $INITIAL_MSGID  = 100; # Why start at 100?  Easier to spot.

my $NCSSHPORT      = 830; # Netconf-over-ssh default port
my $NCDELIM        = ']]>]]>'; # Netconf-over-ssh message delimiter.
my $XMLNS_NCBASE   = "urn:ietf:params:xml:ns:netconf:base:1.0";
my $NCCAP_BASE     = "urn:ietf:params:netconf:base:1.0";

# Return codes from doRPC()
sub NCRPCOK()       { return 1; }
sub NCRPCDATA()     { return 2; }
sub NCRPCRAWRES()   { return 3; }
sub NCRPCERR()      { return 4; }

my @CAPABILITY_URNS = ($NCCAP_BASE,);
my @DEF_EDIT_OPTS   = ("merge","replace","none");

##############################################################################
#
# Constructor/destructor and utility functions follow.
#

#
# Create a new Netconf adapter object.  
#
# hostname and username components are required.  password, port & debug level
# are optional.
#
sub new($$;$) {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $name = shift;
    my $options = shift;
    my $debuglevel = shift;

    # Create the actual object
    my $self = {};

    # Init debug level
    if (defined($debuglevel)) {
        $self->{DEBUG} = $debuglevel;
    } else {
        $self->{DEBUG} = 0;
    }

    # store our device name.
    $self->{NAME} = $name;

    # Must pass in some kind of user name.
    $self->{USERNAME} = $options->{USERNAME};
    if (!$self->{USERNAME}) {
	warn "libNetconf: ERROR: must supply username!\n";
	return undef;
    }

    if (exists($options->{SSHKEY})) {
	$self->{SSHKEY} = $options->{SSHKEY};
    }
    elsif (defined($options->{"PASSWORD"})) {
	$self->{PASSWORD} = $options->{PASSWORD};
    }
    else {
	$self->{PASSWORD} = "";
    }

    # Different port?
    if (defined($options->{PORT})) {
	$self->{PORT} = $options->{PORT};
    } else {
	$self->{PORT} = $NCSSHPORT;
    }

    # Set initial message ID to use.
    $self->{MSGID} = $INITIAL_MSGID;

    if ($self->{DEBUG}) {
        print "libNetconf initializing for $self->{NAME}, " .
            "debug level $self->{DEBUG}\n" ;
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

# Ensure all of the objects we are storing get de-allocated when an instance
# of this class goes away.
sub DESTROY($) {
    my ($self,) = @_;

    if ($self->{SESS}) {
	$self->_closeSession();
    }
    $self->{SESS} = undef;
}

#
# Set/unset/query debug level
#
sub debug($;$) {
    my ($self,$level) = @_;
    
    if (defined($level)) {
	$level =~ /^\d+$/ or
	    die "Debug level must be a positive integer or zero!";
	$self->{DEBUG} = $level;
    }

    return $self->{DEBUG};
}

#
# Debug print wrapper function
#
sub debugpr($$;$) {
    my ($self, $msg, $level) = @_;

    # Default to debug level '1' if not specified.
    $level ||= 1;

    if ($self->{DEBUG} >= $level) {
	print $msg;
    }
}

#
# Pretty print a parsed XML::LibXML DOM object.  Requires a separate
# perl module.  Assumes you are passing in a valid DOM object!
#
sub XMLPrettyPrint($) {
    my ($xmldom,) = @_;
    my $retstr;

    eval { require XML::LibXML::PrettyPrint };
    if ($@) {
	$retstr = $xmldom->toString(2) . "\n";
    } else {
	my $pp = XML::LibXML::PrettyPrint->new(indent_string => "  ");
	$retstr = $pp->pretty_print($xmldom->documentElement()->cloneNode(1))->toString();
    }

    return $retstr;
}

##############################################################################
#
# 'Private' class functions section
#

#
# Create an Expect object that spawns an ssh process to the switch and
# logs in.  Also grab the initial Netconf "hello" from the switch, and
# send our own hello message.
#
sub _expectConnect($)
{
    my $self = shift;
    my $id = "$self->{NAME}::expectConnect()";
    my $error = "";
    my $spawn_cmd =
	"ssh -s -o StrictHostKeyChecking=no -o IdentitiesOnly=yes ".
	"-o UserKnownHostsFile=/dev/null ".
	"-p $self->{PORT} -l $self->{USERNAME} ".
	(exists($self->{SSHKEY}) ? "-i " . $self->{SSHKEY} . " " : "") .
	"$self->{NAME} netconf";

    $self->debugpr("$id: $spawn_cmd\n", 2);

    # Create Expect object and initialize it:
    my $exp = new Expect();
    if (!$exp) {
        # upper layer will check this
        return 0;
    }
    $exp->raw_pty(1);
    $exp->log_stdout(0);

    if ($self->{DEBUG} > 1) {
	$exp->log_file($DEBUG_LOG,"w");
	$exp->debug(1);
    }

    if (!$exp->spawn($spawn_cmd)) {
	warn "$id: Cannot spawn $spawn_cmd: $!\n";
	return 0;
    }

    $exp->expect($CONN_TIMEOUT,
         [" password:" => 
	  sub { my $e = shift;
		$e->send($self->{PASSWORD}."\n");
		exp_continue;}],
         ["ermission denied" => sub { $error = "Password incorrect!";} ],
	 ["authentication failure" => sub { $error = "Password incorrect!";} ],
         [ timeout => sub { $error = "Timeout connecting to switch!";} ],
	 [ eof => sub { $error = "Connection unexpectedly closed!";} ],
         $NCDELIM);

    if (!$error && $exp->error()) {
	$error = $exp->error();
    }

    if ($error) {
	warn "$id: Could not connect to switch: $error\n";
	return 0;
    }

    # Send our "Hello" message.
    my $hellodoc = $self->_mkNCHelloXML();
    my $docstr = $hellodoc->serialize() . $NCDELIM;
    $docstr =~ s/[\n\r]//g;
    $self->debugpr("Sending Hello:\n" . XMLPrettyPrint($hellodoc), 2);
    $exp->send($docstr);
    #sleep 1;
    #$exp->send("\n");

    # Snap up the initial Netconf "Hello" message from switch.
    $self->{SWITCH_HELLO} = $exp->before();
    $self->debugpr("Switch Hello:\n". $self->{SWITCH_HELLO} ."\n", 2);

    # Store it, yo.
    $self->{SESS} = $exp;

    return 1;
}

#
# Make the Netconf client "hello" message (XML doc).
#
sub _mkNCHelloXML($) {
    my ($self,) = @_;

    # Create Boilerplate XML.
    my $dom = XML::LibXML->createDocument("1.0", "UTF-8");
    #$dom->setStandalone(0);

    my $root  = $dom->createElementNS($XMLNS_NCBASE, "hello");
    $dom->setDocumentElement($root);
    my $topcapel = $dom->createElement("capabilities");
    $root->addChild($topcapel);

    foreach my $capurn (@CAPABILITY_URNS) {
	my $capel  = $dom->createElement("capability");
	$capel->appendText($capurn);
	$topcapel->appendChild($capel);
    }

    return $dom;
}

#
# Assemble an RPC XML message based on input args.
#
sub _mkRPCXML($$$) {
    my ($self, $cmd, $xmlparams) = @_;

    # Create XML doc.
    my $dom = XML::LibXML->createDocument("1.0", "UTF-8");
    #$dom->setStandalone(0);

    my $msgid = $self->_nextMsgID();
    my $root = $dom->createElementNS($XMLNS_NCBASE, "rpc");
    $root->setAttribute("message-id", $msgid);
    $dom->setDocumentElement($root);

    my $cmdnode = $dom->createElement($cmd);
    $root->appendChild($cmdnode);

    if ($xmlparams) {
	if (ref($xmlparams) eq 'ARRAY') {
	    foreach my $xml (@{$xmlparams}) {
		$cmdnode->appendChild($xml);
	    }
	} else {
	    $cmdnode->appendChild($xmlparams);
	}
    }

    return $dom;
}

#
# Do what the function says!  Decode response to send back to user. We check
# for a variety of things in the response; make sure it's valid, has the
# expected top-level element, matching RPC message-id, etc.
#
sub _decodeRPCReply($$) {
    my ($self, $rawresp) = @_;

    # Parse the XML encoded response from the gateway into a DOM object.
    # Note: will harf up a die() exception if the result isn't valid XML.
    my $respdom = eval { XML::LibXML->load_xml(string => $rawresp) };
    if ($@) {
	warn "Invalid Netconf RPC response (not XML?): $@";
	return undef;
    }

    $self->debugpr("Decoding:\n". XMLPrettyPrint($respdom), 2);

    # Make sure this is an "rpc-reply" response.
    my $root = $respdom->documentElement();
    if ($root->nodeName() ne "rpc-reply") {
	warn "Netconf RPC response is not an 'rpc-reply'!\n";
	return undef;
    }

    # Make sure the message id attribute is present, and matches what we
    # set in the original call.
    my $msgid = $root->getAttribute("message-id");
    if (!$msgid) {
	warn "Invalid or missing message-id in Netconf RPC reply!\n";
	return undef;
    }
    my $curmsgid = $self->_getCurMsgID();
    if ($msgid != $curmsgid) {
	warn "RPC message-id does not match that of call ($msgid != $curmsgid)\n";
	return undef;
    }

    # Search for any errors returned by the switch first.
    my @rpc_errors = $root->getChildrenByLocalName("rpc-error");
    if (@rpc_errors) {
	warn "Netconf RPC error(s) detected!\n";
	return [NCRPCERR(), $self->_decodeRPCErrors(\@rpc_errors)];
    }

    # If there is an "ok" element, it should be a lone wolf.
    my ($ok_el,) = $root->getChildrenByLocalName("ok");
    if ($ok_el) {
	return [NCRPCOK(), undef];
    }

    # If there is a data element, it should be a singleton.
    my ($data_el,) = $root->getChildrenByLocalName("data");
    if ($data_el) {
	return [NCRPCDATA(), $data_el];
    }

    # Unknown result data. Just pass back first child element "raw",
    # if there are any children.
    if ($root->hasChildNodes()) {
	return [NCRPCRAWRES(), $root->firstChild()];
    }

    # Should not get here!
    warn "Could not parse Netconf RPC response!\n";
    $self->debugpr(XMLPrettyPrint($respdom));
    return undef;
}

#
# Break Netconf RPC error structures into a more convenient hash for
# the caller to inspect.
#
sub _decodeRPCErrors($$) {
    my ($self, $rpcerrors) = @_;
    my $errorlist = [];

    foreach my $err (@{$rpcerrors}) {
	my $errent = {};

	# Can I just say how much I despise XML namespaces?
        my $xpc = XML::LibXML::XPathContext->new($err);
        $xpc->registerNs('x', $XMLNS_NCBASE);

	$errent->{type} = $xpc->findvalue("x:error-type");
	$errent->{tag} = $xpc->findvalue("x:error-tag");
	$errent->{severity} = $xpc->findvalue("x:error-severity");
	$errent->{path} = $xpc->findvalue("x:error-path");
	$errent->{message} = $xpc->findvalue("x:error-message");
        $errent->{message} =~ s/^\s*(.+)\s*$/$1/;
	($errent->{info},) = $err->getChildrenByLocalName("error-info");

	push @{$errorlist}, $errent;
    }

    $self->debugpr(Dumper($errorlist));

    return $errorlist;
}

#
# Cleanly close the Netconf session.  Called by the class destructor.
#
sub _closeSession($) {
    my ($self,) = @_;
    
    my $res = $self->doRPC("close-session");
    if ($res && $res->[0] eq NCRPCERR()) {
	warn "Error closing Netconf session with $self->{NAME}!\n";
    }
}

#
# Monotonically increasing message id number functions.
#
sub _nextMsgID($) {
    my ($self,) = @_;

    return ++$self->{MSGID};
}

sub _getCurMsgID($) {
    my ($self,) = @_;

    return $self->{MSGID};
}

##############################################################################
#
# "Public" class interface follows.
#

#
# Primary Netconf RPC invocation interface.
#
# Args: $cmd - Netconf top-level command to exec (e.g., get, edit-config).
#       $xmlparams - Either a reference to an XML:LibXML::Node (element) 
#                    object, or a reference to an array of such objects. 
#                    These will be packed in as child elements of the RPC 
#                    call.
#
# Returns: 'undef' - An internal error occured, or bad parameters were
#                    passed to the function.
#          [<code>, $obj] - 
#              If command was successful, but returned no data, then
#              return code is '0' and $obj is undef. If the command
#              returns data (get, get-config), then return code is '1'
#              and $obj is the returned data as an XML::LibXML::Node
#              object (tree). If an error occured on the switch, then
#              the return code is '3', and $obj is a reference to an
#              array of error hash objects (parsed from Netconf error
#              structures).
#
sub doRPC($$;$) {
    my ($self, $cmd, $xmlparams) = @_;

    my $error = "";

    my $xmldoc = $self->_mkRPCXML($cmd, $xmlparams);
    if (!$xmldoc) {
	warn "Could not encode Netconf RPC command!\n";
	return undef;
    }

    if (!$self->{SESS}) {
	if (!$self->_expectConnect()) {
	    warn "Could not start Netconf session with $self->{NAME}\n";
	    return undef;
	}
    }

    my $exp = $self->{SESS};
    my $docstr = $xmldoc->serialize() . $NCDELIM;
    #$docstr =~ s/[\n\r]//g;  # Need line endings for CLI commands...
    $self->debugpr("Submitting: ". XMLPrettyPrint($xmldoc), 2);

    sleep 1;
    $exp->send($docstr);
    #sleep 1;
    #$exp->send("\n");
    $exp->expect($CLI_TIMEOUT,
         [ timeout => sub { $error = "Timeout waiting for response!";} ],
	 [ eof => sub { $error = "Connection unexpectedly closed!";} ],
         $NCDELIM);

    if (!$error && $exp->error()) {
	$error = $exp->error();
    }

    if ($error) {
	warn "Error while executing Netconf RPC: $error\n";
	return undef;
    }

    my $response = $exp->before();
    if (!$response) {
	warn "No response received for Netconf RPC: $cmd\n";
	return undef;
    }

    return $self->_decodeRPCReply($response);
}

#
# The Netconf 'get' RPC (convenience wrapper).
#
# Args: $filter - An XML::LibXML:Node object (tree) that encodes a valid
#                 Netconf get filter
#
# Returns: See doRPC(). Returns set of data (counters, whatever) requested.
#
sub doGet($;$) {
    my ($self, $filter) = @_;
    return $self->_doGetOp("get", $filter);
}

#
# The Netconf 'get-config' RPC  (convenience wrapper).
#
# Args: $source - Source for fetching config data (running, candidate, etc.)
#       $filter - An XML::LibXML:Node object (tree) that encodes a valid
#                 Netconf get filter
#
# Returns: See doRPC().  Returns chunk of config requested.
#
sub doGetConfig($;$$) {
    my ($self, $filter, $source) = @_;
    return $self->_doGetOp("get-config", $filter, $source);
}

#
# Not a public function, but here because both 'get' calls above are just
# stubs that call this.
#
sub _doGetOp($$;$$) {
    my ($self, $getop, $filter, $source) = @_;
    my @XMLARGS = ();

    if ($getop eq "get-config") {
	if (defined($source)) {
	    $source = lc($source);
	    if (!($source eq "running" || $source eq "candidate")) {
		warn "Invalid source: $source\n";
		return undef;
	    }
	} else {
	    $source = "running";
	}

	my $src_el = XML::LibXML::Element->new("source");
	$src_el->appendChild(XML::LibXML::Element->new($source));
	push @XMLARGS, $src_el;
    }

    if ($filter) {
	if (!ref($filter) || !$filter->isa("XML::LibXML::Node")) {
	    warn "Input filter needs to be a valid XML::LibXML::Node object!\n";
	    return undef;
	}
	my $fname = $filter->nodeName();
	if ($fname ne "filter") {
	    warn "Top-level filter XML node must be called 'filter' (was: $fname)\n";
	    return undef;
	}
	push @XMLARGS, $filter;
    }

    return $self->doRPC($getop, \@XMLARGS);
}

#
# Convenience wrapper for 'edit-config' Netconf RPC.
#
# Args: $xmlconf - XML::LibXML::Node object (tree) that contains the config
#                  to apply. Should NOT be wrapped in a "config" element!
#       $target  - Target config to edit (e.g. candidate, running).
#       $defop   - Default edit operation ('merge', 'replace', or 'none').
#
# Returns: See doRPC(). 'OK' if config applied cleanly, errors otherwise.
#
sub doEditConfig($$;$$) {
    my ($self,$xmlconf,$target,$defop) = @_;

    my @XMLARGS = ();

    if (!ref($xmlconf) || !$xmlconf->isa("XML::LibXML::Node")) {
	warn "Input configuration must be an XML::LibXML::Node object!\n";
	return undef;
    }

    if ($xmlconf->nodeName() eq "config") {
	warn "Top-level XML element should NOT be 'config'!\n";
	return undef;
    }

    if ($target) {
	$target = lc($target);
	if (!($target eq "running" || $target eq "candidate")) {
	    warn "Invalid config target: $target\n";
	    return undef;
	}
    } else {
	$target = "running";
    }
    my $targ_el = XML::LibXML::Element->new("target");
    $targ_el->appendText($target);
    push @XMLARGS, $targ_el;

    if ($defop) {
	$defop = lc($defop);
	if (!grep {/^$defop$/} @DEF_EDIT_OPTS) {
	    warn "Invalid edit-config default operation: $defop\n";
	    return undef;
	}
	my $defop_el = XML::LibXML::Element->new("default-operation");
	$defop_el->appendText($defop);
	push @XMLARGS, $defop_el;
    }

    my $conf_el = XML::LibXML::Element->new("config");
    $conf_el->setNamespace($XMLNS_NCBASE,"xc",0);
    $conf_el->addChild($xmlconf);
    push @XMLARGS, $conf_el;

    return doRPC("edit-config", \@XMLARGS);
}
