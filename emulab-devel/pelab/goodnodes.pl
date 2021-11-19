#!/usr/bin/perl -w
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

#
# - Find a set of fully connected nodes from the list of nodes at
#     boss:/proj/tbres/plab-reliable-list
# - Size of desired set given as a parameter
# - + The sites containing the nodes must have both latency and bw 
#     data in the past XXX hours (XXX<24)
#   + The set will not contain more than one node from a site
# - Run this on ops.


#
# TODO:
# - add options for time window
#


#use diagnostics;
use strict;
use English;
use Getopt::Std;
use lib '/usr/testbed/lib';
use libxmlrpc;

my $allnodeFile = "/share/planetlab/reliable_nodes";
my $NLIST = "/usr/testbed/bin/node_list";
my $pprefix = "plab";
my $windowHrsDef = 6;

# Turn off line buffering on output
$| = 1;

sub usage {
        print "Usage: $0 [-e pid/eid] [-f blacklistfilename] [-t type] [-v] ".
            "[-m meastype] [-s searchtype] <numNodes>\n";
        return 1;
}
my ($pid, $eid);
my $blacklistfilename;
my $type = "";
my $meastype = "both";
my $searchtype = "maxclique";
my $verbose = 0;
my ($t0, $t1);
my %opt = ();
getopts("0:1:e:f:t:vm:s:", \%opt);
if ($opt{e}) {
    ($pid,$eid) = split('/', $opt{e});
} else {
    $pid = "tbres"; $eid = "pelabbgmon";
}
if ($opt{f}) { $blacklistfilename = $opt{f}; }
if ($opt{t}) { $type = $opt{t}; }
if ($opt{m}) { $meastype = $opt{m}; }
if ($opt{s}) { $searchtype = $opt{s}; }
if ($opt{v}) { $verbose = 1; }
if ($opt{0}) { $t0 = $opt{0}; } else { $t0 = time()-$windowHrsDef*60*60; }
if ($opt{1}) { $t1 = $opt{1}; }
elsif($opt{0}) { $t1 = $t0+$windowHrsDef*60*60; }
else { $t1 = time(); }
if (@ARGV !=1) { exit &usage; }
if (($meastype ne 'lat') && ($meastype ne 'bw') && ($meastype ne 'both')) {
    print "Wrong value of meastype (-m option). It can be only".
	  "'lat', 'bw', or 'both' \n";
    exit 1;
}

if (($searchtype ne 'fastfallible') && ($searchtype ne 'maxclique')) {
    print "Wrong value of searchtype (-s option). It can be only".
	  "'fastfallible' or 'maxclique'\n";
    exit 1;
}


#
# These are globals
#
my $numnodes = $ARGV[0];
my @allnodes = ();      #nodes to consider, in order of desirablility (?)
my %expnodes = ();  #nodes making up eid/pid
my %blacknodes = ();#nodes not allowed to be chosen (deleted from allnodes)

#
# Get list of possible nodes
#
open FILE, "< $allnodeFile"
    or die "Can't open file";
my @allnodesinfo = <FILE>;
foreach my $nodeinfo (@allnodesinfo){
    my @fields = split /\s+/, $nodeinfo;
    #we only want the plabxxx value (for now)
    push @allnodes, $fields[0];
    #print "$fields[0]\n";
}
close FILE;
if ($verbose) {
    print "Read " . scalar(@allnodes) . " nodes from reliable nodes file\n";
}

#
# get list of blacklisted nodes
#
if( defined $blacklistfilename ){
    open FILE, "< $blacklistfilename"
        or die "Can't open file";
    my @blacklist = <FILE>;
    chomp @blacklist;
    foreach my $node (@blacklist){
        $blacknodes{$node} = 1;
        print "blacknode: $node\n";
    }
    close FILE;
}


###############################################################################
# Keep nodes given in pid/eid in hash for quick access.
if( defined($pid) && defined($eid) ){
#    print "reading $pid/$eid nodes\n";
    #add exp nodes to a hash
    my @expnodelist = split('\s+', `$NLIST -H -e $pid,$eid`);
    chomp(@expnodelist);
    foreach my $node (@expnodelist) {
        if ($node =~ /^(${pprefix}\d+)=([\w,]*)$/) {
            my $pnode = $1;
            my $types = $2;
            my @types = split(/,/,$types);
            if ($type && ! grep(/^$type$/,@types)) {
                #print "Skipping $pnode ($type,$types)\n";
                next;
            }
#            print "$vnode ($pnode)\n";
            $expnodes{$pnode} = 1;  #set this node
        }
    }
    #delete nodes from allnodes not found in given experiment
    for( my $i=0; $i < scalar(@allnodes); $i++ ){
        if( !defined $expnodes{$allnodes[$i]} ||
            defined $blacknodes{$allnodes[$i]})
        {
#            print "removing $allnodes[$i] from set\n";
            splice( @allnodes, $i, 1 );
            $i--;
        }else{
#            print "$allnodes[$i]\n";
        }
    }
#    chomp @allnodes;
}else{
    #remove blacknodes
    for( my $i=0; $i < scalar(@allnodes); $i++ ){
        if( defined $blacknodes{$allnodes[$i]})
        {
#            print "removing $allnodes[$i] from set\n";
            splice( @allnodes, $i, 1 );
            $i--;
        }else{
#            print "$allnodes[$i]\n";
        }
    }
}

#print "allnodes[".scalar(@allnodes-1]=$allnodes

#print "%%%%%%\n@allnodes\n%%%%%%%%%%";


#
# Send candidate node list to flexlab xmlrpc server.
#

my ($DEF_HOST,$DEF_PORT,$DEF_URL) = ('ops.emulab.net','3993','/');

my $xurl = "http://${DEF_HOST}:${DEF_PORT}${DEF_URL}";
my $xargs = { 'size' => $numnodes,
              'nodefilter' => \@allnodes,
              'meastype' => $meastype,
              'searchtype' => $searchtype,
              'filtertype' => 1 };
my $respref = libxmlrpc::CallMethodHTTP($xurl,'flexlab.getFullyConnectedSet',
    $xargs);

if (!defined($respref)) {
    print STDERR "ERROR: did not get response from server!\n";
    exit(3);
}

my %resp = %$respref;

if (exists($resp{'httpcode'}) && $resp{'httpcode'} != 400) {
    print STDERR "ERROR: http code " . $resp{'httpcode'} . "; http msg '" . 
        $resp{'httpmsg'} . "'\n";
    exit(4);
}

if ($resp{'code'} ne 0) {
    print STDERR "ERROR: xmlrpc code " . $resp{'code'} . ", fault msg '" . 
	$resp{'output'} . "'\n";
    exit(5);
}

#
# Must be a success.
#
print "" . join(',',@{$resp{'value'}}). "\n";
exit(0);
