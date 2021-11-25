#!/usr/bin/perl -w

use snmpit_libNetconf;
use XML::LibXML;

if (@ARGV < 3) {
    print "Usage: $0 <switch_host> <username[:pass]> <netconf-command> <XML-args>";
    exit 1;
}

my ($switch, $user, $cmd, $xmlarg) = @ARGV;
my $pass;
($user, $pass) = split(/:/, $user);

my $parser = XML::LibXML->new();

my $argnode;

if ($xmlarg) {
    my $argfrag = eval { $parser->parse_balanced_chunk($xmlarg) };
    if ($@) {
	print "Error parsing XML argument: $@\n";
	exit 1;
    }
    $argnode = $argfrag->firstChild();
}

my $args = {
    "USERNAME"  => $user,
    "PASSWORD"  => $pass,
    "PORT"      => undef,
};

my $ncconn = snmpit_libNetconf->new($switch, $args);
$ncconn->debug(1);
if (!$ncconn) {
    print "Could not create new Netconf object for $switch!\n";
    exit 1;
}

my $res;

SWITCH: for ($cmd) {
    /^get$/ && do {
	$res = $ncconn->doGet($argnode);
	last SWITCH;
    };

    /^get-config$/ && do {
	$res = $ncconn->doGetConfig($argnode);
	last SWITCH;
    };

    /^edit-config$/ && do {
	$res = $ncconn->doEditConfig($argnode);
	last SWITCH;
    };

    # default
    $res = $ncconn->doRPC($cmd, $argnode);
}

if ($res && $res->[0] eq 2) {
    print $res->[1]->toString() ."\n";
}
