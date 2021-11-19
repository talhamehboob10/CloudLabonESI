#!/usr/bin/perl -w

# Force10 Expect wrapper testing harness.

use strict;
use English;
use Getopt::Std;

use force10_expect;

my @get_test1 = (
    ["name", "Basic command execution test #1"],
    ["cmd", "show version | no-more"],
    ["cmd", "show vlan | no-more"],
    ["cmd", "badcmd"],
    ["cmd", "badagain"],
    ["cmd", "show hosts"],
);

my @timeout_test1 = (
    ["cmd", "show system"]
);

my @config_test1 = (
    ["config", "snmp-server contact Kirk Webb"],
    ["config", "snmp-server location DDC"],
    ["config", "derp-derp"]
);

my @iface_config_test1 = (
    ["ifconfig", "name testing_lan", "vlan666"],
    ["ifconfig", "derp", "vlan666"]
);

# List the tests to run here.
my @testsets = (\@get_test1,\@config_test1,\@iface_config_test1);

my %opts = ();

if (!getopts("n:p:d:",\%opts)) {
    print "Usage: $0 -n <switch_name> -p <password> -d <level>\n";
    exit 1;
}

my $switch = "";
my $pass   = "";
my $debug  = 0;
$switch = $opts{'n'} or die "Must specify switch name!";
$pass   = $opts{'p'} or die "Must specify password!";
$debug  = $opts{'d'} || 0;

my $wrapper = force10_expect->new($switch, $debug, $pass);

foreach my $tlist (@testsets) {
    my @results = ();
    my $testname = "unnamed";

    foreach my $cmd (@{$tlist}) {
        TESTSW1: for ((@{$cmd})[0]) {
	    /^name$/ && do {
		$testname = (@{$cmd})[1];
		print "========== Running Test: $testname ==========\n";
		last TESTSW1;
	    };
	
	    /^cmd$/ && do {
		push @results, ($wrapper->doCLICmd((@{$cmd})[1]))[1];
		last TESTSW1;
	    };

	    /^config$/ && do {
		push @results, ($wrapper->doCLICmd((@{$cmd})[1],1))[1];
		last TESTSW1;
	    };

	    /^ifconfig$/ && do {
		push @results, ($wrapper->doCLICmd((@{$cmd})[1],1,(@{$cmd})[2]))[1];
		last TESTSW1;
	    };

	    # Default
	    print "Error: Unknown command: $_\n";
	}
    }

    print "--- Results:\n";
    my $i = 1;
    foreach my $resstr (@results) {
	print "*** Submission $i: $resstr\n\n";
	++$i;
    }

}
