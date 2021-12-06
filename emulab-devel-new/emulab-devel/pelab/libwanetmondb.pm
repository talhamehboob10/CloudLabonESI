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
# TODO:
#  - Don't connect to DB every query. Leave connection open util
#    another DB needs to be connected to (DG 1/3/07), unless the 
#    "connect" subroutine already does this...
#

package libwanetmondb;

use strict;
use Exporter;
use vars qw(@ISA @EXPORT);
use lib '/usr/testbed/lib';
use libtbdb;
require Exporter;

@ISA    = "Exporter";
our @EXPORT = qw ( 
                   getRows
              );
our @EXPORT_OK = qw(
                    );

my $PWDFILE = "/usr/testbed/etc/pelabdb.pwd";
my $OPSDBNAME  = "pelab";
my  $DPDBNAME  = "nodesamples";
my $DPDBHOST = "nfs.emulab.net";
my $DBUSER  = "flexlabdata";
my $OpsDataDuration = 24; #hours that data persists on the ops DB
my $dbpwd;
my $dppwd;
if (`cat $PWDFILE` =~ /^([\w]*)\s([\w]*)$/) {
    $dbpwd = $1;
    $dppwd = $2;
}
else {
    fatal("Bad characters in password!");
}
$dbpwd = '';

#
# Return an array of result row hashes based on given query string.
#   If a unixstamp range is not given, data from ops is used
#   If given unixstamp range falls within the past hour, and goes back over
#   ($OpsDataDuration-1) in time, then the query only uses the datapository
#   and WILL NOT LOOK AT data within the last hour
#
sub getRows($)
{
    my ($query) = @_;
    my ($tablename, $t0,$t1);
    my $useOps = 1;
    my @rows = ();

    if( $query =~ /from\s+(\w+)/ ){
        $tablename = $1;
    }
    if( $query =~ /unixstamp\s*>=?\s*(\d+)/ ){
        $t0 = $1;
    }
    if( $query =~ /unixstamp\s*<=?\s*(\d+)/ ){
        $t1 = $1;
    }

    if( !defined $t0 || !defined $t1 ){
        #use Ops
        $useOps = 1;
    }
#    print "t0=$t0\nt1=$t1\n$query\n";

    #Determine whether to go to DPos or Ops databases
    if( defined $t0 &&
        $t0 < time()-($OpsDataDuration-0.5)*60*60 )
    {
        #use DataPository
        $useOps = 0;
    }else{
        #use Ops DB
        $useOps = 1;
    }



    if( $useOps ){
#        print "USING OPS\n";
        TBDBConnect($OPSDBNAME, $DBUSER, $dbpwd,"") == 0
            or die("Could not connect to ops/pelab database!\n");
        my $query_result = DBQueryFatal($query);
        if (! $query_result->numrows) {
#            warn("No results from OpsDB with query:\n$query\n");
            return @rows;
        }
        while( my $hrow = $query_result->fetchrow_hashref() ){
            push @rows, $hrow;
        }
    }else{
#        print "USING DP: $query\n";
        TBDBConnect($DPDBNAME, $DBUSER, $dbpwd,$DPDBHOST) == 0
            or die("Could not connect to nfs/pelab database!\n");
        my $query_result = DBQueryFatal($query);
        if (! $query_result->numrows) {
#            warn("No results from DataPository DB with query:\n$query\n");
            return @rows;
        }
        while( my $hrow = $query_result->fetchrow_hashref() ){
            push @rows, $hrow;
        }
#        print "finished DP\n";
    }

    return @rows;
}




1;  # DON'T REMOVE THIS


