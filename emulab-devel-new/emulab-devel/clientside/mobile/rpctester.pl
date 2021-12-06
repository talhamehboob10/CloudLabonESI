#!/usr/bin/perl -w

use strict;
use English;
use libjsonrpc;
use Data::Dumper;

my $TMPFILE = "/tmp/footest.tmp";

print "Encoding func with single scalar arg\n";
my $json1 = EncodeCall("scalarargfunc", 1);
print "Encoded as: $json1\n\n";

print "Encoding func with no args\n";
my $json2 = EncodeCall("noargfunc");
print "Encoded as: $json2\n\n";

print "Encoding func with array args\n";
my $json3 = EncodeCall("arrayfunc", ["foo","bar","baz"]);
print "Encoded as: $json3\n\n";

print "Encoding func with hash args\n";
my $json4 = EncodeCall("hashfunc", {FOO => 1, BAR => 2});
print "Encoded as: $json4\n\n";

print "Encoding func with bad arguments (circular ref)\n";
my $dee = {};
my $dum = { DEE => $dee };
$dee->{DUM} = $dum;
my $badjson = EncodeCall("badargs", [$dee, $dum]);
if (!$badjson) {
    print "No return value\n\n";
} else {
    print "Encoded as: $badjson\n\n";
}

print "'Sending' RPC\n";
my $memvar;
open(my $fh, ">", $TMPFILE) or
    die "Could not open $TMPFILE for writing!\n";
my $ret = SendRPCData($fh, $json3);
print "Retval: $ret\n";
print "Sent as: ". `cat $TMPFILE` ."\n";

print "'Sending' another RPC same FH\n";
$ret = SendRPCData($fh, $json4);
print "Retval: $ret\n";
print "Sent as: ". `cat $TMPFILE` ."\n";

print "Sending with undefined data arg.\n";
$ret = SendRPCData($fh, undef);
print "Retval: $ret\n\n";

print "Sending with empty data arg.\n";
$ret = SendRPCData($fh, "");
print "Retval: $ret\n\n";

print "Sending to bogus filehandle.\n";
my $bogus = "asdf";
$ret = SendRPCData($bogus, $json1);
print "Retval: $ret\n\n";

print "Receiving from $TMPFILE!\n";
close $fh;
open ($fh, "<", $TMPFILE) or 
    die "Could not open $TMPFILE for reading!\n";
my $data1 = RecvRPCData($fh);
print "Received: $data1\n";

print "Receiving again from $TMPFILE...\n";
my $data2 = RecvRPCData($fh);
print "Received: $data2\n";

print "Decoding first read from $TMPFILE.\n";
my $dec1 = DecodeRPCData($data1);
print "Decoded as: ". Dumper($dec1);

print "Decoding second read from $TMPFILE.\n";
my $dec2 = DecodeRPCData($data2);
print "Decoded as: ". Dumper($dec2);

print "Receiving from STDIN...\n";
my $count = 0;
do {
    my $data = RecvRPCData(*STDIN, 10);
    if (!$data) {
	print "No data received.\n";
    } elsif ( $data =~ /^-1$/) {
	print "Timeout!\n";
    } else {
	print "Received data: $data\n";
	print "Attemping to decode:\n";
	my $decoded = DecodeRPCData($data);
	if (!$decoded) {
	    print "Nothing decoded!\n";
	} else {
	    print "Data decoded as: ". Dumper($data);
	}
    }
    $count++;
} while ($count < 10);
close($fh);
print "Done\n";
