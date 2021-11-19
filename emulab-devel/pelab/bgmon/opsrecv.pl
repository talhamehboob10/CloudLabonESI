#!/usr/bin/perl
#
# Copyright (c) 2006 University of Utah and the Flux Group.
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

########################
# TODO:
# 1) provide a coherency protocol to the site/node id cache
# 2) buffer updates to 1 per 5 seconds (or so)
#######################


#
# Configure variables
#

use lib '/usr/testbed/lib';
use libtbdb;
use libwanetmon;
use Getopt::Std;
use strict;
use IO::Socket::INET;
use IO::Select;
use Time::HiRes qw(gettimeofday);

# node and site id caches
my %nodeids;
my %siteids;

# ipaddr cache, since nodes are addressed via IP in the event system.
my %ipaddrs;

# Batch up insertions. Simple string.
my $insertions = "";
my @queued_data;
my $batchsize  = 0;
my $maxbatch   = 30;
my $maxidletime= 5;	# Seconds before forced insert.
my $lastinsert = 0;	# Timestamp.

my %lasttimestamp;  #prevents adding duplicate entries in DB
my %duplicatecnt;   #counters keeping track of duplicate entries.
my $duplicateKillThresh = 50; #kill node if this many duplicates occur per index

#
# Turn off line buffering on output
#
$| = 1;

sub usage {
	print "Usage: $0 [-p receiveport] [-a sendport] [-e pid/eid]".
	    " [-d debuglevel] [-i]\n";
	return 1;
}

my $debug    = 0;
my $impotent = 0;
my $debug = 0;
my ($port, $sendport, $expid);
my %opt = ();
if (!getopts("p:a:e:d:ih", \%opt)) {
    exit &usage;
}
if ($opt{p}) { $port = $opt{p}; } else { $port = 5051; }
if ($opt{a}) { $sendport = $opt{a}; } else { $sendport = 5050; }
if ($opt{h}) { exit &usage; }
if ($opt{e}) { $expid = $opt{e}; } else { $expid = "none"; }
if ($opt{d}) { $debug = $opt{d}; } else { $debug = 0; }
if ($opt{i}) { $impotent = 1; } 

if (@ARGV !=0) { exit &usage; }

print "pid/eid = $expid\n";
print "receiveport = $port\n";
print "sendport = $sendport\n";

my $PWDFILE = "/usr/testbed/etc/pelabdb.pwd";
##TODO: CHANGE TO "pelab" and "pelab"
my $DBNAME = "pelab";
my $DBUSER = "pelab";
my $DBErrorString = "";
#TODO: change this back to file
#my $DBPWD = "";
my $DBPWD = `cat $PWDFILE`;
if( $DBPWD =~ /^([\w]*)\s([\w]*)$/ ) {
    $DBPWD = $1;
}else{
    fatal("Bad chars in password!");
}

#connect to database
my ($DB_data, $DB_sitemap);
TBDBConnect($DBNAME,$DBUSER,$DBPWD);

# set sql_mode to STRICT_ALL_TABLES to match it with
# dp database mode
DBQueryWarn("set SESSION sql_mode='STRICT_ALL_TABLES'");

my $socket_rcv = IO::Socket::INET->new( LocalPort => $port,
					Proto     => 'udp' );
#my $socket_snd = IO::Socket::INET->new( PeerPort => $sendport,
#					Proto    => 'udp',
#					PeerAddr => "$linksrc");


my $sel = IO::Select->new();
$sel->add($socket_rcv);

#
# MAIN LOOP
#

while (1) {

    #check for pending received events
#    event_poll_blocking($handle, 1000);

    SendBatchedInserts()
	if ($batchsize && (time() - $lastinsert) > $maxidletime);

    handleincomingmsgs();

}

#############################################################################

exit(0);


sub handleincomingmsgs()
{
    my $inmsg;
    #check for pending received results
    my @ready = $sel->can_read(1000);
    foreach my $handle (@ready){
	$socket_rcv->recv( $inmsg, 2048 );
	chomp $inmsg;
	print "debug: got a udp message: $inmsg\n" if( $debug > 2 );
	my %inhash = %{ deserialize_hash( $inmsg )};
#	foreach my $key (keys %inhash){
#	    print "key=$key\n";
#	    print "$key  \t$inhash{$key}\n";
#	}
	my ($exp_in, $linksrc, $linkdest, $testtype, $result, $tstamp, $index)
	    = ($inhash{expid}, $inhash{linksrc}, $inhash{linkdest},
	       $inhash{testtype}, $inhash{result}, $inhash{tstamp},
	       $inhash{index});

	# if incoming result is not of this expid, return
	if( $exp_in ne $expid ){
	    print "ignored msg from expid=$exp_in\n" if( $debug > 2 );
	    return;
	}

	print "\n" if( $debug > 1 );
	print("linksrc =$linksrc\n".
	      "linkdest=$linkdest\n".
	      "testtype=$testtype\n".
	      "result  =$result\n".
	      "index   =$index\n".
	      "tstamp  =$tstamp\n") if( $debug > 1 );

	if( defined $linksrc ){
	    my $socket_snd;
	    eval{
		$socket_snd = 
		  IO::Socket::INET->new( PeerPort => $sendport,
					 Proto    => 'udp',
					 PeerAddr => "$linksrc");
	    };
	    if( $@ ){
		#socket creation was fatal
		warn "Socket creation failed: $@\n";
	    }
	    my %ack = ( expid   => $expid,
			cmdtype => "ACK",
			index   => $index,
			tstamp  => $tstamp );
	    if( defined %ack && defined $socket_snd ){
		my $ack_serial = serialize_hash( \%ack );
		$socket_snd->send($ack_serial);
		print "**SENT ACK**\n" if( $debug > 1 );

		if( !defined $lasttimestamp{$linksrc}{$index} ||
		    $tstamp ne $lasttimestamp{$linksrc}{$index} )
		{
		    saveTestToDB(linksrc   => $linksrc,
				 linkdest  => $linkdest,
				 testtype  => $testtype,
				 result    => $result,
				 tstamp    => $tstamp );
		    #clear duplicatecnt for corresponding result index
		    if( defined($duplicatecnt{$linksrc}{$index}) ){
			delete $duplicatecnt{$linksrc}{$index};
		    }
		}else{
		    print("++++++duplicate data\n".
		          "linksrc=$linksrc\n".
			  "linkdest=$linkdest\n".
			  "testtype =$testtype\n".
			  "result=$result\n".
			  "index=$index\n".
			  "tstamp=$tstamp\n") if( $debug > 0);

		    #increment duplicatecnt for this src and index number
		    if( defined($duplicatecnt{$linksrc}{$index}) ){
			$duplicatecnt{$linksrc}{$index}++;
			#kill off offending node, if > threshold
			if( $duplicatecnt{$linksrc}{$index}
			    > $duplicateKillThresh )
			{
			    killnode($linksrc);
			    print "KILLING OFF BGMON at $linksrc".
				" for index $index\n" if( $debug > 0 );
			    delete $duplicatecnt{$linksrc};
			}
		    }else{
			$duplicatecnt{$linksrc}{$index} = 1;
		    }
		    

		}
		$lasttimestamp{$linksrc}{$index} = $tstamp;
	    }

	}

    }

}


#############################################################################

sub saveTestToDB()
{
    my %results = @_;

    my @tmp;
    my ($srcsite, $srcnode, $dstsite, $dstnode);

    if( !exists $siteids{$results{linksrc}} ){
	@tmp = DBQuery("SELECT site_idx FROM site_mapping ".
		       "WHERE node_id='$results{linksrc}'") ->fetch;
	$srcsite = $tmp[0][0];
	$siteids{$results{linksrc}} = $srcsite;
    }else{
	$srcsite = $siteids{$results{linksrc}};
    }
    if( !exists $nodeids{$results{linksrc}} ){       
	@tmp = DBQuery("SELECT node_idx FROM site_mapping ".
		       "WHERE node_id='$results{linksrc}'") ->fetch;
	$srcnode = $tmp[0][0];
	$nodeids{$results{linksrc}} = $srcnode;
    }else{
	$srcnode = $nodeids{$results{linksrc}};
    }
    if( !exists $siteids{$results{linkdest}} ){
	@tmp = DBQuery("SELECT site_idx FROM site_mapping ".
		       "WHERE node_id='$results{linkdest}'") ->fetch;
	$dstsite = $tmp[0][0];
	$siteids{$results{linkdest}} = $dstsite;
    }else{
	$dstsite = $siteids{$results{linkdest}};
    }
    if( !exists $nodeids{$results{linkdest}} ){
	@tmp = DBQuery("SELECT node_idx FROM site_mapping ".
		       "WHERE node_id='$results{linkdest}'") ->fetch;
	$dstnode = $tmp[0][0];
	$nodeids{$results{linkdest}} = $dstnode;
    }else{
	$dstnode = $nodeids{$results{linkdest}};
    }

    my $testtype = $results{'testtype'};
    my $result   = $results{'result'};
    my $tstamp   = $results{'tstamp'};
    my $latency  = ($testtype eq "latency" ? "$result" : "NULL");
    my $loss     = ($testtype eq "loss"    ? "$result" : "NULL");
    my $bw       = ($testtype eq "bw"      ? "$result" : "NULL");

    # TODO: hacky... log "outage" markers of 100% loss
    if( $testtype eq "outage" && $result eq "down"){
	$loss = "1";
	print "     LOSS = 100%\n\n" if( $debug > 2 );
    }


    # Check for valid DB id's.. RETURN from sub if invalid
    if( $srcsite eq "" || $srcnode eq "" || $dstsite eq "" || $dstnode eq "" ){
	warn "No results matching node id's $results{linksrc} and/or ".
	    "$results{linkdest}. Results:\n";
	warn "srcsite=$srcsite\n";
	warn "srcnode=$srcnode\n";
	warn "dstsite=$dstsite\n";
	warn "dstnode=$dstnode\n";
	return;
    }
   
    

    if ($bw eq "") {
	my $src = $results{'linksrc'};
	my $dst = $results{'linkdest'};
	
	warn("BW came in as null string at $tstamp for $src,$dst\n");
	return;
    }
    if ($latency eq "") {
	my $src = $results{'linksrc'};
	my $dst = $results{'linkdest'};
	
	warn("Latency came in as null string at $tstamp for $src,$dst\n");
	return;
    }

    if ($batchsize == 0) {
	$insertions =
		"INSERT INTO pair_data (srcsite_idx, srcnode_idx, ".
		"dstsite_idx, dstnode_idx, unixstamp, ".
		"latency, loss, bw) values ";
    }
    $insertions .= ","
	if ($batchsize);

    $insertions .=
	"($srcsite, $srcnode, $dstsite, $dstnode, $tstamp, ".
	" $latency, $loss, $bw)";
    push @queued_data, sprintf("RECORD ADDED $results{linksrc} $results{linkdest} : %.6f", $results{tstamp});

    $batchsize++;
    SendBatchedInserts()
	if ($batchsize > $maxbatch);
}

sub SendBatchedInserts()
{
    if ($batchsize) {
	DBQueryWarn($insertions)
	    if (!$impotent);
	print "$insertions\n"
	    if ($debug > 2);
	$lastinsert = time();
    }
    my ($seconds, $microseconds) = gettimeofday;
    my $time = $seconds + $microseconds/1000000;
    foreach my $d (@queued_data) {
      printf "$d %.6f\n", $time;
    }
    $batchsize  = 0;
    $insertions = "";
    @queued_data = ();
}


#############################################################################
