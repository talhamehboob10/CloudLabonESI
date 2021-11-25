#!/usr/bin/perl -w
#
# EMULAB-COPYRIGHT
# Copyright (c) 2004-2011, 2013 University of Utah and the Flux Group.
# All rights reserved.
#
use English;
use Getopt::Std;

use lib '/usr/testbed/lib';
use libtestbed;

my @VARS = ("GENIRACK_COMMUNITY",
	    "GENIRACK_SWITCH_PASSWORD",
	    "GENIRACK_ILO_PASSWORD",
	    "PROTOGENI_PASSWORD",
	    "ELABMAN_SSLCERT_PASSWORD");

foreach my $var (@VARS) {
    my $pswd = TBGenSecretKey();
    $pswd = substr($pswd, 0, 12);
    print "${var}=$pswd\n";
}
